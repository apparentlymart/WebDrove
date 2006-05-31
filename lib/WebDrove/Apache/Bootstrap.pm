#!/usr/bin/perl

package WebDrove::Apache::Bootstrap;

use WebDrove;
use WebDrove::Logging;
use WebDrove::Apache::Handler;
#use Apache::CompressClientFixup;
use Digest::MD5;
use Storable;
#use Unicode::MapUTF8 ();
use DBI;

my $log = WebDrove::Logging::get_logger();

# Called once on server startup
sub handle_start {

	$log->info("WebDrove for mod_perl initializing");

    # The goal here is to pull in as many libraries as possible
    # during Apache initialization so that when Apache forks
    # child processes all of the libraries will already be present.
    #
    # A bunch of libraries were loaded with "use" statements above,
    # but some libraries like to delay-load components, which we don't
    # want them to do here.

    DBI->install_driver("mysql");

    # Give any extra local code the opportunity to initialize pre-fork
    eval { handle_start_local(); };

}

# Called every time the server restarts
sub handle_restart {

	$log->info("WebDrove for mod_perl restarting");

    # Here we add some stuff to httpd.conf so that loading WebDrove is a one-liner

    Apache->httpd_conf(qq{

PerlInitHandler WebDrove::Apache::Handler
#PerlFixupHandler Apache::CompressClientFixup


    });

    eval { handle_restart_local(); };

}

handle_start();

1;
