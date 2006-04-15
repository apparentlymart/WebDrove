#!/usr/bin/perl

## Module that handles the loading of the configuration file
## and some other setup tasks that must always be done before
## WebDrove's libraries can be used.

BEGIN {
    unless ($ENV{WDHOME}) {
        print STDERR "No WDHOME environment variable set! Please set it to the root of your WebDrove install.";
        die(undef);
    }
}

package WebDrove::Config;

use strict;

my $cfg;
if ($ENV{WDCONFIG}) {
    $cfg = $ENV{WDCONFIG};
}
else {
    $cfg = "$ENV{WDHOME}/local/wdconfig.pl";
}

unless (-f $cfg) {
    print STDERR "Unable to load configuration file $cfg\n";
    die(undef);
}

require $cfg;
if ($@) {
    print STDERR "There was an error while processing the configuration file\n";
    print STDERR $@;
    die(undef);
}

use lib "$ENV{WDHOME}/lib";
use lib "$ENV{WDHOME}/local/lib";  # Site-local Libraries
use lib "$ENV{WDHOME}/ext/lib";  # External Libraries

1;
