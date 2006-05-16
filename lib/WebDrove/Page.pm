
package WebDrove::Page;

use WebDrove;
use WebDrove::DB;
use WebDrove::S2;
use WebDrove::PageType;
use strict;

sub new {
    my ($class, $pagemeta) = @_;

    return bless $pagemeta, $class;
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
    return "/".WebDrove::eurl($_[0]->title)."/";
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
    return $_[0]->{title};
}

sub owner {
    return $_[0]->{owner};
}

sub s2_context {
    my ($self) = @_;

    return $self->{s2ctx} if defined $self->{s2ctx};

    my $style = $self->style;

    return $self->{s2ctx} = $style->make_context();
}

sub s2_object {
    my ($self) = @_;

    return $self->{s2obj} if defined $self->{s2obj};

    my $type = $self->type;
    my $ctx = $self->s2_context();

    return $self->{s2obj} = $type->construct_s2_object($self, $ctx);
}

sub get_content_xml {
    my ($self, $xml) = @_;

    my $type = $self->type;
	return $type->get_content_xml($self, $xml);
}

1;
