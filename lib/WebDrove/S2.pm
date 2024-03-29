#!/usr/bin/perl

package WebDrove::S2;

use strict;
use WebDrove::S2::Style;
use WebDrove::S2::Layer;

use S2::Runtime::OO;

my $s2 = new S2::Runtime::OO;
my $log = WebDrove::Logging::get_logger();

sub make_context {
    my ($layers) = @_;

    # Can pass in a style as the first argument, in which case its layers are used
    $layers = $layers->get_layers() if ($layers->isa('WebDrove::S2::Style'));

	$log->logdie("Can't make context with no layers") unless @$layers;

	$log->debug("Making S2 context for layers ", sub { join(',', map { $_->layerid } @$layers); });

	my %layermap = ();

    my $ctx = $s2->make_context(map { my $s2l = $_->get_raw_s2_object(); $layermap{$_->uniq()} = $_; $s2l; } @$layers);
    $ctx->[S2::Runtime::OO::Context::SCRATCH] = {
    	"layermap" => \%layermap,
    };

    return $ctx;
}

sub compile_layer_source {
    my ($sourceref) = @_;

    return $s2->layer_from_string($sourceref);
}

sub install_system_layer {
    my ($sourceref, $checker, $parent) = @_;

    my $news2layer = $s2->layer_from_string($sourceref);
    my @inc = sort keys %INC;
    my $uniq = $news2layer->get_layer_info("uniq");

    $log->logdie("All system layers must declare 'uniq' layerinfo") unless $uniq;

    my $oldlayer = WebDrove::S2::Layer->find_by_uniq($uniq);

    if ($oldlayer) {
    	my $oldparentid = $oldlayer->parent() ? $oldlayer->parent()->layerid : undef;
    	my $parentid = $parent ? $parent->layerid : undef;
    	unless ($oldparentid == $parentid) {
    		$log->logdie("Can't reparent an existing layer (changing parent from $oldparentid to $parentid)");
    	}
    }

    my $newlayer;

    if ($oldlayer) {
        # Need to update an existing layer

        $oldlayer->replace_with($sourceref, $checker);
        $newlayer = $oldlayer;
    }
    else {
        # Need to create a new layer
        $newlayer = new WebDrove::S2::Layer($sourceref, $checker, $parent);
    }

    return $newlayer;
}

sub get_public_layers {
	my ($type, $parent) = @_;

	my $query = "SELECT layerid FROM s2layer WHERE siteid=0";
	my @args = ();

	if (defined($type)) {
		$query .= " AND type=?";
		push @args, $type;
	}

	if (defined($parent)) {
		my $layerid = $parent->layerid;
		my $siteid = $parent->owner ? $parent->owner->siteid : 0;
		$query .= " AND parentid=? AND parentsiteid=?";
		push @args, $layerid, $siteid;
	}

	$log->debug("Fetching public layers: Executing query $query with args ".join(',',@args));

	my $dbh = WebDrove::DB::get_db_reader();
	my $sth = $dbh->prepare($query);
	$sth->execute(@args);

	my @ret = ();

	while (my ($layerid) = $sth->fetchrow_array()) {
		push @ret, WebDrove::S2::Layer->fetch(undef, $layerid);
	}

	return \@ret;
}

package WebDrove::S2::Builtin;

sub ehtml {
    my ($ctx, $s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;#"#
    $s =~ s/'/&#39;/g;
    return $s;
}

sub Page__print_head {
    my ($ctx, $this) = @_;

    $ctx->_print("<link rel=\"stylesheet\" type=\"text/css\" href=\"/_/stylesheet\" />\n");

}

sub Page__print_body {
    my ($ctx, $this) = @_;

    my $page = $this->{_page};
    my $s2pagebody = $this->{_s2pagebody};
    my $pctx = $page->s2_context();
    $pctx->set_print(sub { print $_[1]; });
    $pctx->run($s2pagebody->{_type}."::print()", $s2pagebody);
}

sub Page__external_props {
	my ($ctx, $this, $schema) = @_;

	return {} unless defined($WDConf::S2_CUSTOM_PROPS{$schema});

    my $page = $this->{_page};
	my $handler = $WDConf::S2_CUSTOM_PROPS{$schema};

	return $handler->($ctx, $page, $schema);
}

sub resource_url_impl {
	my ($ctx, $fn) = @_;

	my $stack = $ctx->get_stack_trace();
	my $latest = $stack->[-1];
	my $layer = $latest->[2];
	my $uniq = $layer->get_layer_info("uniq");
	my $layerid = $ctx->[S2::Runtime::OO::Context::SCRATCH]{layermap}{$uniq}->layerid();

	return "$WDConf::STATIC_MEDIA_URL/$layerid/$fn";

}

1;

