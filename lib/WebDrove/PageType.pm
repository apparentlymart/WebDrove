
package WebDrove::PageType;

use WebDrove;
use WebDrove::Config;
use WebDrove::DB;
use WebDrove::S2;
use strict;

my $log = WebDrove::Logging::get_logger();

sub fetch {
    my ($class, $typeid) = @_;

    my $self = {
        typeid => $typeid,
        name => undef,
        displayname => undef,
        constructor => undef,
        s2core => undef,
    };

    return bless $self, $class;
}

sub fetch_by_name {
	my ($class, $name) = @_;

	$log->debug("Fetching PageType $name");

    my $db = WebDrove::DB::get_db_reader();
    my $meta = $db->selectrow_hashref("SELECT typeid,name,displayname,corelayerid FROM pagetype WHERE name = ?", undef, $name);
    my $self = {};

	if (! $meta) {
		$log->debug("Failed to load PageType $name");
		return undef;
	}

    $self->{typeid} = $meta->{typeid};
    $self->{name} = $meta->{name};
    $self->{displayname} = $meta->{displayname};
    $self->{s2core} = WebDrove::S2::Layer->fetch(undef, $meta->{corelayerid});
    $self->{pkg} = $WDConf::PAGE_TYPE{$meta->{name}};
	$self->{meta_loaded} = 1;

    return bless $self, $class;
}

sub typeid {
	$log->logcroak("Invalid PageType object (no typeid)") unless $_[0]->{typeid};
    return $_[0]->{typeid};
}

# private function - lazily load data, but load it all at once.
sub load_metadata {
    my ($self) = @_;

    return 0 if $self->{meta_loaded};

    my $typeid = $self->typeid;
    my $db = WebDrove::DB::get_db_reader();
    my $meta = $db->selectrow_hashref("SELECT name,displayname,corelayerid FROM pagetype WHERE typeid = ?", undef, $typeid);

    $self->{name} = $meta->{name};
    $self->{displayname} = $meta->{displayname};
    $self->{s2core} = WebDrove::S2::Layer->fetch(undef, $meta->{corelayerid});
    $self->{pkg} = $WDConf::PAGE_TYPE{$meta->{name}};

    return $self->{meta_loaded} = 1;
}

sub construct_s2_object {
    my ($self, $page, $ctx) = @_;

    $self->load_metadata();
    my $pkg = $self->{pkg};
    my $name = $self->{name};

    return undef unless $pkg;
    return undef if $name =~ /\W/;

    return $pkg->s2_object($page, $ctx, "page_$name");
}

sub s2_core_layer {
    my ($self) = @_;

    $self->load_metadata();
    return $self->{s2core};
}

sub name {
    my ($self) = @_;

    $self->load_metadata();
    return $self->{name};
}

sub displayname {
    my ($self) = @_;

    $self->load_metadata();
    return $self->{displayname};
}

sub get_content_xml {
	my ($self, $page, $xml) = @_;

    $self->load_metadata();
    my $pkg = $self->{pkg};
    my $name = $self->{name};

    return undef unless $pkg;
    return undef if $name =~ /\W/;

    return $pkg->get_content_xml($xml, $page, "page_$name");
}

sub set_content_xml {
	my ($self, $page, $elem) = @_;

    $self->load_metadata();
    my $pkg = $self->{pkg};
    my $name = $self->{name};

    return undef unless $pkg;
    return undef if $name =~ /\W/;

    return $pkg->set_content_xml($elem, $page, "page_$name");
}

1;
