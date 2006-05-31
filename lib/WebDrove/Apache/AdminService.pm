
package WebDrove::Apache::AdminService;

use strict;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Apache::Handler;
use WebDrove::Apache::AdminService::Sites;
use POSIX qw(strftime);
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

my $log = WebDrove::Logging::get_logger();

sub handler {
    my $r = shift;

    $r->content_type("text/xml");

    my $uri = $r->uri;
    return not_found($r) if ($uri ne '/' && $uri =~ m!/$!);

    my @pathbits = split(m!/!, $r->uri);
    shift @pathbits; # Get rid of the empty element caused by the initial slash

    # Root Service Information Page
    return root_service($r) if (scalar(@pathbits) == 0);

    my @remaining_bits = @pathbits;
    shift @remaining_bits;

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
                Elem("site", abs_url($r, "/sites")),
                Elem("s2layer", abs_url($r, "/s2/layers")),
            ),
            Elem("links",
                Elem("sites",
                	Elem("create" => abs_url($r, "/sites/create")),
                ),
            ),
        ),
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

sub xmltime {
    my ($timestamp) = @_;

    my $tz = strftime("%z", localtime($timestamp));
    $tz =~ s/(\d{2})(\d{2})/$1:$2/;

    return strftime("%Y-%m-%dT%H:%M:%S", localtime($timestamp)).$tz;
}

sub Elem {
    return new XMLElem(@_);
}

sub Attrib {
    return [ $_[0], $_[1] ];
}

sub logged_error_response {
	my ($response_code, $errmsg) = @_;
	$log->error("$response_code $errmsg");
	return $response_code;
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
    	if (ref $kid) {
	        $ret .= $kid;
    	}
    	else {
	        $ret .= exml($kid);
    	}
    }

    #$ret .= "\n" unless (scalar(@$kids) == 1 && ref $kids->[0] eq '');

    $ret .= "</$tagname>";

    $ret .= "\n";

    return $ret;

}

sub exml {
    my ($str) = @_;
    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/"/&quot;/g; #"
    return $str;
}

package WebDrove::Apache::AdminService::XMLBuilder;

sub new {
	my ($class) = @_;
	my $s = "";
	return bless \$s, $class;
}

sub attrib {
	return WebDrove::Apache::AdminService::Attrib($_[1], $_[2]);
}

sub elem {
	my $self = shift;
	return WebDrove::Apache::AdminService::Elem(@_);
}

1;
