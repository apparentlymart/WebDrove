#!/usr/bin/perl

package WebDrove::S2;

use strict;
use WebDrove::S2::Style;
use WebDrove::S2::Layer;

use S2::Runtime::OO;

my $s2 = new S2::Runtime::OO;

sub make_context {
    my ($layers) = @_;
    
    # Can pass in a style as the first argument, in which case its layers are used
    $layers = $layers->get_layers() if ($layers->isa('WebDrove::S2::Style'));

    return $s2->make_context(map { $_->get_raw_s2_object() } @$layers);
}

sub compile_layer_source {
    my ($sourceref) = @_;
    
    return $s2->layer_from_string($sourceref);
}

1;
