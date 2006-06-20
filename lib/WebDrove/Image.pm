
package WebDrove::Image;

use WebDrove;
use strict;

# FIXME: Can't instatiate logger here because this gets called before the logger library is loaded! :(
#my $log = WebDrove::Logging::get_logger();

sub fetch {
	my ($class, $site, $imageid) = @_;

    my $meta = $site->db_selectrow_hashref("SELECT * FROM image WHERE siteid=? AND imageid=?", $site->siteid, $imageid);
    return undef unless $meta;
    $meta->{owner} = $site;

    return $class->_new_from_meta($meta);
}

sub list_images_by_site {
	my ($class, $site) = @_;

    my $sth = $site->db_prepare("SELECT * FROM image WHERE siteid=?");
    $sth->execute($site->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $site;
        push @ret, $class->_new_from_meta($meta);
    }

    return \@ret;
}

sub list_images_by_site_and_ids {
	my ($class, $site, @ids) = @_;

	return () unless @ids;

    my $sth = $site->db_prepare("SELECT * FROM image WHERE siteid=? AND imageid IN (".join(',',map{$_+0}@ids).")");
    $sth->execute($site->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $site;
        push @ret, $class->_new_from_meta($meta);
    }

    return \@ret;
}

sub imageid {
	return $_[0]->{imageid};
}

sub _new_from_meta {
    my ($class, $imagemeta) = @_;

    return bless $imagemeta, $class;
}

sub width {
	return $_[0]->{width}+0;
}
sub height {
	return $_[0]->{height}+0;
}
sub format {
	return $_[0]->{format};
}

1;
