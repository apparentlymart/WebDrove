
package WebDrove::Request;

use WebDrove::Logging;

my $log = WebDrove::Logging::get_logger();

# Abstract base class for page requests

sub method { $log->logdie("->method not implemented for $_[0]") }
sub pathbits { $log->logdie("->pathbits not implemented for $_[0]") }
sub site { $log->logdie("->site not implemented for $_[0]") }
sub get_arg { $log->logdie("->get_arg not implemented for $_[0]") }
sub post_arg { $log->logdie("->post_arg not implemented for $_[0]") }

1;
