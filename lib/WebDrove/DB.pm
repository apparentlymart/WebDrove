
package WebDrove::DB;

use DBI;
use WebDrove::Config;
use strict;

# For now we just have one DB handle per Apache child and use it for everything.
# Moving forward we will need to implement a multi-db role-based setup where
# load can be spread sensibly over multiple DB hosts.

my $cached_dbh = undef;

# Internal function which will eventually encapsulate all the logic for DB load-balancing,
# role selection and whatnot. Callers should use the wrapper functions that follow.
sub get_dbh() {
    return $cached_dbh if $cached_dbh;
    my $dbconfig = \%WDConf::DBCONFIG;
    my $dsn = "DBI:mysql:database=".$dbconfig->{database}.";host=".$dbconfig->{host}.";port=".($dbconfig->{port} || 3306);
    return $cached_dbh = DBI->connect($dsn, $dbconfig->{user}, $dbconfig->{password}, {'RaiseError' => 1});
}

sub get_db_reader() {
    return get_dbh();
}

sub get_db_writer() {
    return get_dbh();
}

sub get_cluster_reader($) {
    # my ($clusterid) = @_;
    return get_dbh();
}

sub get_cluster_writer($) {
    # my ($clusterid) = @_;
    return get_dbh();
}

sub alloc_system_id {
    my ($area) = @_;
    return alloc_id(get_db_writer(), 0, $area);
}

# Most callers shouldn't call this directly, but instead call either alloc_system_id or
# $site->alloc_id, which are wrappers around this function that know the correct $dbh to pass.
sub alloc_id {
    my ($dbh, $siteid, $area, $recursing) = @_;
    
    $siteid += 0;
    die "No dbh provided" unless $dbh;

    # Must make sure that we use the same dbh throughout to get the right id
    my $present = $dbh->do("UPDATE counter SET max=LAST_INSERT_ID(max+1) WHERE siteid=? AND area=?", undef, $siteid, $area);
    
    if ($present) {
        return $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
    }
    
    # If we're recursing (see below) and it's not present then something bad has happened. Bail out!
    die "Failed to allocate $area id for site $siteid" if $recursing;
    
    # If we've got this far, then caller is asking for a counter that's never been allocated before.
    # We need to initialize the counter with an appropriate value.
    
    my $lockname = "counteralloc-$siteid-$area";
    my $locked = $dbh->selectrow_array("SELECT GET_LOCK(?,5)", undef, $lockname);
    die "Failed to aquire counter lock for $area in site $siteid" unless $locked;

    my $newmax = undef;
    
    if ($area eq 's2style') {
        $newmax = $dbh->selectrow_array("SELECT MAX(styleid) FROM s2style WHERE siteid=?", undef, $siteid);
    }
    elsif ($area eq 's2layer') {
        $newmax = $dbh->selectrow_array("SELECT MAX(layerid) FROM s2layer WHERE siteid=?", undef, $siteid);
    }
    elsif ($area eq 'page') {
        $newmax = $dbh->selectrow_array("SELECT MAX(pageid) FROM page WHERE siteid=?", undef, $siteid);
    }
    else {
        die "Unknown counter area '$area'";
    }
    
    # Insert a row describing the max we just found.
    # Another process might beat us to it and allocate first but it doesn't really matter.
    $dbh->do("INSERT IGNORE INTO counter (siteid, area, max) VALUES (?, ?, ?)", undef, $siteid, $area, $newmax);
    
    $dbh->selectrow_array("SELECT RELEASE_LOCK(?)", undef, $lockname);
    
    # Now call this function again recursively to get an id from the newly-defined area
    return alloc_id($siteid, $area, 1);
}

1;
