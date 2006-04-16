
package WebDrove::PageType;

use WebDrove;
use WebDrove::Config;
use WebDrove::DB;
use WebDrove::S2;
use strict;

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

sub typeid {
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
    $self->{constructor} = $WDConf::PAGE_CONSTRUCTOR{$meta->{name}};
    
    return $self->{meta_loaded} = 1;
}

sub construct_s2_object {
    my ($self, $page, $ctx) = @_;
    
    $self->load_metadata();
    my $cons = $self->{constructor};
    my $name = $self->{name};
    
    return undef unless ref $cons eq 'CODE';
    return undef if $name =~ /\W/;
    
    return $cons->($page, $ctx, "page_$name");
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

1;
