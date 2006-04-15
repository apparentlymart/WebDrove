#!/usr/bin/perl

# Main WebDrove Library
#
# Note: This library is used both by the webapp running in Apache and by the
#  command line utilities, so it can't load or use anything that isn't available
#  in both contexts.

package WebDrove;

use WebDrove::Config;
use WebDrove::DB;
use strict;



1;
