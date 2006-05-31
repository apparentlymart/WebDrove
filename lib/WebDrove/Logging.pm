
package WebDrove::Logging;

use Log::Log4perl;

my $log;

# Return an appropriate logger for the caller based on the caller's package
sub get_logger {
	return Log::Log4perl::get_logger(scalar(caller(0)));
}

BEGIN {
	if ($WDConf::LOG_CONFIG && -f $WDConf::LOG_CONFIG) {
		Log::Log4perl->init_and_watch($WDConf::LOG_CONFIG, 120) if ($WDConf::LOG_CONFIG && -f $WDConf::LOG_CONFIG);
	}
	else {
		die("Unable to load log config file $WDConf::LOG_CONFIG. Must set \$WDConf::LOG_CONFIG to point at a Log4perl configuration file.");
	}
	$log = get_logger();
	$log->debug("Logger startup succeeded");
}

1;
