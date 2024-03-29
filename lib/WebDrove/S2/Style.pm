
package WebDrove::S2::Style;

use strict;
use WebDrove;
use WebDrove::S2;
use Carp qw(croak);

my $log = WebDrove::Logging::get_logger();

sub fetch {
    my ($class, $site, $styleid) = @_;

    my $self = {
        'site' => $site,
        'styleid' => $styleid,
        'layers' => undef,
        'modtime' => undef,
        'name' => undef,
    };

    return bless $self, $class;
}

sub new {
	my ($class, $site, $corelayer) = @_;

	my $layerid = $corelayer->layerid;
	my $layersite = $corelayer->owner;
	my $siteid = $site->siteid;
	my $layersiteid = ($layersite ? $layersite->siteid : 0);

	$log->debug("Creating new style for site ".$siteid);

	my $styleid = $site->alloc_id("s2style");
	return undef unless $styleid;

	my $success = $site->db_do("INSERT INTO s2style (styleid,siteid,modtime) VALUES (?,?,NOW())", $styleid, $siteid);
	if (! $success) {
		$log->error("Failed to create new style for site ".$siteid);
		return undef;
	}

	$success = $site->db_do("INSERT INTO s2stylelayer (siteid, styleid, type, layerid, layersiteid) VALUES (?,?,?,?,?)", $siteid, $styleid, "core", $layerid, $layersiteid);
	if (! $success) {
		$log->error("Failed to set core layer for new style ".$styleid." owned by site ".$siteid);
		return undef;
	}

	return $class->fetch($site, $styleid);
}

sub get_site_styles {
	my ($class, $site) = @_;

	my $siteid = $site->siteid;

	my $sth = $site->db_prepare("SELECT styleid, name, UNIX_TIMESTAMP(modtime) FROM s2style WHERE siteid=?");
    $sth->execute($siteid);

	my @ret = ();
	while (my ($styleid, $name, $modtime) = $sth->fetchrow_array()) {
		my $item = WebDrove::S2::Style->fetch($site, $styleid);
		$item->{name} = $name;
		$item->{modtime} = $modtime;
		push @ret, $item;
	}

	return \@ret;
}

sub styleid {
	$log->logcroak("Invalid style object (no styleid)") unless $_[0]->{styleid};
    return $_[0]->{styleid};
}

sub _load_meta {
	my ($self) = @_;

	return if (defined $self->{modtime} && defined $self->{name});

	my $site = $self->{site};

    my $sth = $site->db_prepare("SELECT name, UNIX_TIMESTAMP(modtime) FROM s2style WHERE styleid=? AND siteid=?");
    $sth->execute($self->styleid, $site->siteid);

	($self->{name}, $self->{modtime}) = $sth->fetchrow_array();

	return 1;
}

sub owner {
	return $_[0]->{site};
}

sub name {
	$_[0]->_load_meta();
	return $_[0]->{name};
}

sub modtime {
	$_[0]->_load_meta();
	return $_[0]->{modtime};
}

sub get_layers {
    my ($self) = @_;

	$log->debug("Getting layers for style ".$self->styleid." owned by site ".$self->owner->siteid);

    return $self->{layers} if defined $self->{layers};

    my $styleid = $self->styleid;
    my $site = $self->{site};
    my $siteid = $site->siteid;

    my %sty = ();
    my $sth = $site->db_prepare("SELECT type, layerid, layersiteid FROM s2stylelayer WHERE siteid=? AND styleid=?");
    $sth->execute($siteid, $styleid);

    while (my ($type, $layerid, $laysiteid) = $sth->fetchrow_array()) {
        my $laysite = WebDrove::Site->fetch($laysiteid);
        my $layer = WebDrove::S2::Layer->fetch($laysite, $layerid) || die "Failed to load $type layer";

        $sty{$type} = $layer;
    }

    my @lay = ();
    foreach my $type (qw(core i18nc layout i18n theme user)) {
        push @lay, $sty{$type} if $sty{$type};
    }

    return $self->{layers} = \@lay;
}

sub set_layer {
	my ($self, $type, $layer) = @_;

	my $layerid = $layer->layerid;
	my $layersiteid = $layer->owner ? $layer->owner->siteid : 0;
	my $site = $self->owner;
	my $siteid = $site->siteid;
	my $styleid = $self->styleid;

	return $site->db_do("REPLACE INTO s2stylelayer (styleid, siteid, type, layerid, layersiteid) VALUES (?,?,?,?,?)", $styleid, $siteid, $type, $layerid, $layersiteid) ? 1 : 0;

}

sub delete_self {
	my ($self) = @_;

	my $siteid = $self->owner->siteid;
	my $styleid = $self->styleid;

	$log->debug("Style $styleid from site $siteid deleting itself");

	my $success = $self->owner->db_do("DELETE FROM s2style WHERE siteid=? AND styleid=?", $siteid, $styleid);

	$log->debug("Failed to delete style $styleid from site $siteid") unless $success;

	return $success ? 1 : 0;

}

sub make_context {
    my ($self) = @_;

	$log->debug("Making S2 context for style ".$self->styleid);

    return WebDrove::S2::make_context($self);
}

1;
