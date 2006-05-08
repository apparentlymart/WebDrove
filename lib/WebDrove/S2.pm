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

sub install_system_layer {
    my ($sourceref, $checker) = @_;

    my $news2layer = $s2->layer_from_string($sourceref);
    my @inc = sort keys %INC;
    my $uniq = $news2layer->get_layer_info("uniq");

    die("All system layers must declare 'uniq' layerinfo") unless $uniq;

    my $oldlayer = WebDrove::S2::Layer->find_by_uniq($uniq);

    my $newlayer;

    if ($oldlayer) {
        # Need to update an existing layer

        $oldlayer->replace_with($sourceref, $checker);
        $newlayer = $oldlayer;
    }
    else {
        # Need to create a new layer
        $newlayer = new WebDrove::S2::Layer($sourceref, $checker);
    }

    return $newlayer;
}

1;
