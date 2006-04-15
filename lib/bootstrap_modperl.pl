#!/usr/bin/perl

use strict;
use lib "$ENV{WDHOME}/lib";
use WebDrove::Apache::Bootstrap;
use Apache;

## So what's going on here, then?
##
## When we include this file in our Apache configuration with PerlRequire,
## Apache loads and runs this file during initial startup. When Apache is
## restarted (via a HUP or USR1 signal) it re-processes its config,
## but since this file has already been loaded once Perl wouldn't run it
## again unless we lie about it to Perl as we do below.
##
## The upshot of this is that this script runs every time Apache starts up,
## even after a restart. WebDrove::Apache::Bootstrap is loaded and processed
## only once, and it contains stuff we only want to do on the initial load.

delete $INC{"$ENV{WDHOME}/lib/bootstrap_modperl.pl"};

WebDrove::Apache::Bootstrap::handle_restart();

1;
