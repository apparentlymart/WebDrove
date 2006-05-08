
package WebDrove::Apache::AdminService::Sites;

use strict;
use WebDrove;
use WebDrove::Apache::Handler;
use WebDrove::Apache::AdminService;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

*redir = \&WebDrove::Apache::AdminService::redir;
*Elem = \&WebDrove::Apache::AdminService::Elem;
*Attr = \&WebDrove::Apache::AdminService::Attr;
*xml = \&WebDrove::Apache::AdminService::xml;
*not_found = \&WebDrove::Apache::AdminService::not_found;

sub service_handler {
    my ($r, $pathbits) = @_;

    my %get = $r->args;

    if (scalar(@$pathbits) == 0) {
        # Doing site discovery
        my $siteid = $get{siteid}+0;
        if ($siteid && WebDrove::Site->fetch($siteid)) {
            return redir($r, "/sites/".$siteid);
        }
        else {
            return not_found($r);
        }
    }

    if (scalar(@$pathbits) == 1) {
        my $siteid = $pathbits->[0];

        my $site = WebDrove::Site->fetch($siteid);

        return not_found($r) unless $site;

        return xml($r,
            Elem("site",
                Elem("name" => $site->name),
            )
        );

    }

    return not_found($r);
}

1;
