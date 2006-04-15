
package WebDrove::Page;

use WebDrove;
use WebDrove::DB;
use WebDrove::S2;
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

sub style {
    my ($self) = @_;

    return $self->{style} if defined $self->{style};

    my $styleid = $self->{styleid};
    my $site = $self->{owner};

    return $self->{style} = WebDrove::S2::Style->fetch($site, $styleid);
}

sub s2_context {
    my ($self) = @_;
    
    return $self->{s2ctx} if defined $self->{s2ctx};
    
    my $style = $self->style;
    
    return $self->{s2ctx} = $style->make_context();
}

sub s2_object {
    my ($self) = @_;
    
    return {
        '_type' => 'Page',
        'title' => $self->{title},
        'content' => '<p>This is not the real body content.</p>',
    };
}

1;
