
package WebDrove::Apache::AdminService;

use strict;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Apache::Handler;
use WebDrove::Apache::AdminService::Sites;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

sub handler {
    my $r = shift;

    $r->content_type("text/xml");

    my $uri = $r->uri;
    return not_found($r) if ($uri ne '/' && $uri =~ m!/$!);

    my @pathbits = split(m!/!, $r->uri);
    shift @pathbits; # Get rid of the empty element caused by the initial slash

    # Root Service Information Page
    return root_service() if (scalar(@pathbits) == 0);

    my @remaining_bits = @pathbits[1,];
    shift @remaining_bits unless defined $remaining_bits[0];

    my $handler = {
        'sites' => \&WebDrove::Apache::AdminService::Sites::service_handler,
    }->{$pathbits[0]};

    return $handler ? $handler->($r, \@remaining_bits) : not_found($r);
}

sub root_service {
    my ($r) = @_;

    return xml($r,
        Elem("webdrove",
            Elem("disco",
                Elem("site", "/sites"),
                Elem("s2layer", "/s2/layers"),
            ),
        )
    );

}



# Utility Functions

sub abs_url {
    my ($r, $path) = @_;

    return "http://".$r->server->server_hostname.$path;
}

sub not_found {
    my ($r) = @_;

    $r->status_line("404 Not Found");

    return xml($r,
        Elem("error",
            Attrib("type" => "not-found"),
        )
    );
}

sub redir {
    my ($r, $path) = @_;

    my $abs_url = abs_url($r, $path);
    $r->status_line("302 Found");
    $r->header_out("Location", $abs_url);

    return xml($r,
        Elem("redirect",
            Attrib("type" => "temporary"),
            Elem("uri", $abs_url),
        )
    );
}

sub xml {
    my ($r, $xml) = @_;

    WebDrove::Apache::Handler::http_header($r);
    print $xml;
    return 200;
}

sub Elem {
    return new XMLElem(@_);
}

sub Attrib {
    return [ $_[0], $_[1] ];
}

package XMLElem;

use overload q{""} => 'as_string';

sub new {
    my ($class, $tagname, @stuff) = @_;

    my @kids = ();
    my %attr = ();

    foreach my $thing (@stuff) {
        if (ref $thing eq 'ARRAY') {
            $attr{$thing->[0]} = $thing->[1];
        }
        else {
            push @kids, $thing;
        }
    }

    my $self = [ $tagname, \@kids, \%attr ];
    return bless $self, $class;
}

sub as_string {
    my ($self) = @_;

    my ($tagname, $kids, $attr) = @$self;

    my $ret = "";

    $ret .= "<$tagname";
    foreach my $k (keys %$attr) {
        $ret .= " $k=\"".($attr->{$k} ? exml($attr->{$k}) : $k)."\"";
    }
    if (scalar(@$kids) == 0) {
        $ret .= " />";
        return $ret;
    }
    $ret .= ">";
    #$ret .= "\n" unless (scalar(@$kids) == 1 && ref $kids->[0] eq '');

    foreach my $kid (@$kids) {
        $ret .= $kid;
    }

    #$ret .= "\n" unless (scalar(@$kids) == 1 && ref $kids->[0] eq '');

    $ret .= "</$tagname>";

    $ret .= "\n";

    return $ret;

}

sub exml {
    my $str = @_;
    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/"/&quot;/g; #"
    return $str;
}

1;
