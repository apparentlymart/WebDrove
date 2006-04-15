
package WebDrove::S2::Style;

use strict;
use WebDrove;
use WebDrove::S2;

sub fetch {
    my ($class, $site, $styleid) = @_;

    my $self = {
        'site' => $site,
        'styleid' => $styleid,
        'layers' => undef,
        'name' => undef,
    };
    
    return bless $self, $class;
}

sub styleid {
    return $_[0]->{styleid};
}

sub get_layers {
    my ($self) = @_;
    
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

sub make_context {
    my ($self) = @_;
    
    return WebDrove::S2::make_context($self);
}

1;
