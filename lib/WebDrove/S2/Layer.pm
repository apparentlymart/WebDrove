
package WebDrove::S2::Layer;

use strict;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use Storable;

sub fetch {
    my ($class, $site, $layerid) = @_;

    my $self = {
        'site' => $site,
        'layerid' => $layerid,
        's2layer' => undef,
    };

    return bless $self, $class;
}

# Create a new layer in the database based on the given source code and checker
sub new {
    my ($class, $sourceref, $checker, $parent, $site) = @_;

    die "Expecting a scalarref compiler output and a checker" unless ref $sourceref eq 'SCALAR' and $checker->isa('S2::Checker');
    die "Creating layers with parents is not yet implemented" if $parent;
    die "Creating non-system layers is not yet implemented" if $site;

    my $news2layer = WebDrove::S2::compile_layer_source($sourceref);
    die "Failed to load layer" unless $news2layer;
    my $layerinfo = $news2layer->get_layer_info();
    my $layertype = $layerinfo->{"type"};

    # Get a layerid. If $site is defined, then we need to allocate the layerid against that site.
    my $layerid;
    if ($site) {
        $layerid = $site->alloc_id("s2layer");
    }
    else {
        $layerid = WebDrove::DB::alloc_system_id("s2layer");
    }

    die "Failed to allocate a layerid" unless $layerid;

    my $db_do;
    my $siteid;
    if ($site) {
        $db_do = sub {
            return $site->db_do(@_);
        };
        $siteid = $site->siteid;
    }
    else {
        my $db = WebDrove::DB::get_db_writer();
        $db_do = sub {
            return $db->do($_[0], undef, @_[1 .. $#_]);
        };
        $siteid = 0;
    }

    $checker->cleanForFreeze();

    my $source = $$sourceref;
    $db_do->("INSERT INTO s2compiled (layerid,siteid,compiletime,layersource) VALUES (?,?,NOW(),?)", $layerid, $siteid, $source) or die("Failed to insert compiled S2 code");
    $db_do->("INSERT INTO s2checker (layerid,siteid,checker) VALUES (?,?,?)", $layerid, $siteid, Storable::freeze($checker)) or die("Failed to insert serialized checker");

    foreach my $k (qw(name uniq)) {
        $db_do->("INSERT INTO s2layerinfo (layerid,siteid,infokey,value) VALUES (?,?,?,?)", $layerid, $siteid, $k, $layerinfo->{$k}) if defined($layerinfo->{$k}) or die("Failed to insert layerinfo $k");
    }

    $db_do->("INSERT INTO s2layer (layerid,parentid,parentsiteid,siteid,type) VALUES (?,NULL,NULL,?,?)", $layerid, $siteid, $layertype) or die("Failed to insert layer metadata");

    return fetch($class, $site, $layerid);
}

sub replace_with {
    my ($self, $sourceref, $checker) = @_;

    die "Expecting a scalarref compiler output and a checker" unless ref $sourceref eq 'SCALAR' and $checker->isa('S2::Checker');

    my $news2layer = WebDrove::S2::compile_layer_source($sourceref);
    die "Failed to load new layer" unless $news2layer;
    my $layerinfo = $news2layer->get_layer_info();
    my $site = $self->owner();

    my $layerid = $self->layerid;

    my $db_do;
    my $siteid;
    if ($site) {
        $db_do = sub {
            return $site->db_do(@_);
        };
        $siteid = $site->siteid;
    }
    else {
        my $db = WebDrove::DB::get_db_writer();
        $db_do = sub {
            return $db->do($_[0], undef, @_[1 .. $#_]);
        };
        $siteid = 0;
    }

    $checker->cleanForFreeze();

    my $source = $$sourceref;
    $db_do->("REPLACE INTO s2compiled (layerid,siteid,compiletime,layersource) VALUES (?,?,NOW(),?)", $layerid, $siteid, $source) or die("Failed to insert compiled S2 code");
    $db_do->("REPLACE INTO s2checker (layerid,siteid,checker) VALUES (?,?,?)", $layerid, $siteid, Storable::freeze($checker)) or die("Failed to insert serialized checker");

    my $values;
    my @param = ();
    my $notin;
    foreach my $k (qw(name uniq)) {
        next unless defined($layerinfo->{$k});
        $values .= "," if $values;
        #$values .= sprintf("(%d, %s, %s)", $lid,
        #                   $dbh->quote($_), $dbh->quote($info{$_}));
        $values .= "(?,?,?,?)";
        push @param, $layerid, $siteid, $k, $layerinfo->{$k};
        $notin .= "," if $notin;
        $notin .= "'$_'";
    }
    if ($values) {
        $db_do->("REPLACE INTO s2layerinfo (layerid, siteid, infokey, value) VALUES $values", @param)
            or die "replace into s2info (values = $values)";
        $db_do->("DELETE FROM s2layerinfo WHERE layerid=? AND infokey NOT IN ($notin)", undef, $layerid);
    }
    #$db_do->("INSERT INTO s2layerinfo (layerid,siteid,infokey,value) VALUES (?,?,?,?)", $layerid, $siteid, $k, $layerinfo->{$k}) if defined($layerinfo->{$k}) or die("Failed to insert layerinfo $k");

}

sub owner {
    return $_[0]->{site};
}

sub find_by_uniq {
    my ($class, $uniq) = @_;

    my $db = WebDrove::DB::get_db_reader();
    my ($layerid) = $db->selectrow_array("SELECT layerid FROM s2layerinfo WHERE siteid=0 AND infokey='uniq' AND value=?", undef, $uniq);

    return undef unless $layerid;

    return fetch($class, undef, $layerid);
}

sub layerid {
    return $_[0]->{layerid};
}

sub get_raw_s2_object {
    my ($self) = @_;

    return $self->{s2layer} if defined $self->{s2layer};

    my $site = $self->owner;
    my $siteid = $site ? $site->siteid : 0;
    my $layerid = $self->layerid;

    my $layersource;

    # Need to handle the special case of system layers, which are owned by fake siteid 0
    # They come from the global database, not from a site cluster.
    my $query = "SELECT layersource FROM s2compiled WHERE siteid = ? and layerid = ?";
    my @quargs = ($siteid, $layerid);
    if ($site) {
        ($layersource) = $site->db_selectrow_array($query, @quargs);
    }
    else {
        my $db = WebDrove::DB::get_db_reader();
        ($layersource) = $db->selectrow_array($query, undef, @quargs);
    }

    return $self->{s2layer} = WebDrove::S2::compile_layer_source(\$layersource);
}

1;
