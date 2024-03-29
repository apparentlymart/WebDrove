
package WebDrove::Page;

use WebDrove;
use WebDrove::DB;
use WebDrove::S2;
use WebDrove::PageType;
use strict;

my $log = WebDrove::Logging::get_logger();

sub fetch {
	my ($class, $site, $pageid) = @_;

    my $meta = $site->db_selectrow_hashref("SELECT * FROM page WHERE siteid=? AND pageid=?", $site->siteid, $pageid);
    return undef unless $meta;
    $meta->{owner} = $site;

    return $class->_new_from_meta($meta);
}

sub fetch_by_title {
	my ($class, $site, $title) = @_;

    my $meta = $site->db_selectrow_hashref("SELECT * FROM page WHERE siteid=? AND title=?", $site->siteid, $title);
    return undef unless $meta;
    $meta->{owner} = $site;

    return $class->_new_from_meta($meta);
}

sub list_pages_by_site {
	my ($class, $site) = @_;

    my $sth = $site->db_prepare("SELECT * FROM page WHERE siteid=? ORDER BY sort");
    $sth->execute($site->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $site;
        push @ret, WebDrove::Page->_new_from_meta($meta);
    }

    return \@ret;
}

sub _new_from_meta {
    my ($class, $pagemeta) = @_;

    return bless $pagemeta, $class;
}

sub new {
	my ($class, $site, $title, $typename) = @_;

	# TODO: After creating the page row, call into the page type handler
	# to get it to build its initial data structures. For now, the
	# static page type handler is just designed to work okay when its
	# data is missing.

	unless ($site && $title && $typename) {
		$log->logdie("Invalid parameters to 'new' method");
	}

	my $siteid = $site->siteid;
	my $pageid = $site->alloc_id("page");

	$log->debug("Creating new page for site ".$site->siteid);

	my $type = WebDrove::PageType->fetch_by_name($typename);
	unless ($type) {
		$log->error("Attempt to create a page of non-existant type $type");
		return undef;
	}

	my $corelayer = $type->s2_core_layer();
	unless ($type) {
		$log->error("Failed to get core layer for page type $type");
		return undef;
	}

	my $style = WebDrove::S2::Style->new($site, $corelayer);
	unless ($style) {
		$log->error("Failed to create new style for a new page of type $type");
		return undef;
	}

	my $typeid = $type->typeid;
	my $styleid = $style->styleid;

	my $success = $site->db_do("INSERT INTO page (pageid,siteid,title,typeid,styleid,sort) VALUES (?,?,?,?,?,?)", $pageid,$siteid,$title,$typeid,$styleid,$pageid);

	return $success ? $site->get_page($pageid) : undef;
}

sub type {
    my ($self) = @_;

    return $self->{type} if defined $self->{type};

    my $typeid = $self->{typeid};

    return $self->{type} = WebDrove::PageType->fetch($typeid);
}

sub pageid {
    return $_[0]->{pageid};
}

sub url {
    return $_[0]->title eq 'Home' ? "/" : "/".WebDrove::eurl($_[0]->title)."/";
}

sub equals {
    return ($_[0]->pageid eq $_[1]->pageid) && ($_[0]->owner->equals($_[1]->owner));
}

sub style {
    my ($self) = @_;

    return $self->{style} if defined $self->{style};

    my $styleid = $self->{styleid};
    my $site = $self->owner();

    return $self->{style} = WebDrove::S2::Style->fetch($site, $styleid);
}

sub title {
	my $self = shift;
	unless ($_[0]) {
	    return $self->{title};
	}
	else {
		my $new = shift;
		my $site = $self->owner();
		my $siteid = $site->siteid;
		my $pageid = $self->pageid;

		my $success = $site->db_do("UPDATE page SET title=? WHERE siteid=? AND pageid=?", $new, $siteid, $pageid);

		$self->{title} = $new if $success;

		return $success ? 1 : 0;
	}
}

sub owner {
    return $_[0]->{owner};
}

sub delete_self {
	my ($self) = @_;

	$log->debug("Page ".$self->pageid." from site ".$self->owner->siteid." deleting itself");

	# Clean up the page style
	my $style = $self->style;
	if (! $style->delete_self()) {
		$log->debug("Failed to delete style for page ".$self->pageid);
		return 0;
	}

	my $siteid = $self->owner->siteid;
	my $pageid = $self->pageid;

	my $success = $self->owner->db_do("DELETE FROM page WHERE siteid=? AND pageid=?", $siteid, $pageid) ? 1 : 0;

	$log->debug("Failed to delete page ".$self->pageid) unless $success;

	return $success;

}

sub s2_context {
    my ($self) = @_;

	$log->debug("Making S2 context for page ".$self->pageid);


    return $self->{s2ctx} if defined $self->{s2ctx};

    my $style = $self->style;
    # TEMP: If the style has no layers, make a new one that works.
    my $layers = $style->get_layers;
    unless (@$layers) {
        my $corelayer = $self->type->s2_core_layer();
        my $site = $self->owner;
        $style = WebDrove::S2::Style->new($site, $corelayer);
        $site->db_do("UPDATE page SET styleid = ? WHERE siteid = ? and pageid = ?", $style->styleid, $site->siteid, $self->pageid);
    }

    return $self->{s2ctx} = $style->make_context();
}

sub s2_object {
    my ($self, $pathbits, $nav) = @_;

    return $self->{s2obj} if defined $self->{s2obj};

    my $type = $self->type;
    my $ctx = $self->s2_context();

    return $self->{s2obj} = $type->construct_s2_object($self, $ctx, $pathbits, $nav);
}

sub s2_layouts {
	my ($self, $layertype) = @_;

	my $pagetype = $self->type();
	return $pagetype->s2_layouts($layertype);
}

sub get_content_xml {
    my ($self, $xml) = @_;

    my $type = $self->type;
	return $type->get_content_xml($self, $xml);
}

sub set_content_xml {
	my ($self, $elem) = @_;

	my $type = $self->type;
	return $type->set_content_xml($self, $elem);
}

sub set_sort_index {
	my ($self, $idx) = @_;

	my $site = $self->owner;
	my $siteid = $site->siteid;
	my $pageid = $self->pageid;

	$log->debug("Page $pageid from site $siteid now has sort index $idx");

	return $site->db_do("UPDATE page SET sort=? WHERE siteid=? AND pageid=?", $idx+0, $siteid, $pageid);
}

1;
