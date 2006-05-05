
package WebDrove::Apache::AdminService;

use strict;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

sub handler {
    my $r = shift;

    $r->content_type("text/html");
    WebDrove::Apache::Handler::http_header($r);

    $r->print("<p>Admin Web Service!</p>");

    return OK;
}

1;
