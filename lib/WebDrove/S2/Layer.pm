
package WebDrove::S2::Layer;

use strict;
use WebDrove;
use WebDrove::S2;

sub fetch {
    my ($class, $site, $layerid) = @_;

    my $self = {
        'site' => $site,
        'layerid' => $layerid,
        's2layer' => undef,
    };
    
    return bless $self, $class;
}

sub layerid {
    return $_[0]->{layerid};
}

sub get_raw_s2_object {
    my ($self) = @_;

    return $self->{s2layer} if defined $self->{s2layer};
    
    my $site = $self->{site};
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
