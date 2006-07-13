
package WebDrove::Apache::Request;

use strict;
use base qw(WebDrove::Request);

use WebDrove::Logging;
my $log = WebDrove::Logging::get_logger();

sub new {
	my ($class, $r, $site) = @_;

	return bless {
		r => $r,
		site => $site,
		get => undef,
		post => undef,
	}, $class;
}

sub method {
	return $_[0]{r}->method;
}

sub path {
	return $_[0]{r}->uri;
}

sub site {
	return $_[0]{site};
}

sub get_arg {
	return $_[0]{get}{$_[1]} if ($_[0]{get});
	$_[0]{get} = $_[0]->_decode_urlencoding(scalar($_[0]{r}->args));
	return $_[0]{get}{$_[1]};
}

sub post_arg {
	return $_[0]{post}{$_[1]} if ($_[0]{post});

	unless ($_[0]->method eq 'POST') {
		$_[0]{post} = {};
		return undef;
	}

	$_[0]{post} = $_[0]->_decode_urlencoding(scalar($_[0]{r}->content));
	return $_[0]{post}{$_[1]};
}

sub _decode_urlencoding {
	my $self = shift;
	my $str = shift;

	my @chunks = split(/&/, $str);
	my %ret;

	foreach my $chunk (@chunks) {
		$chunk =~ s/\+/ /g;

		my ($k, $v) = split(/=/, $chunk, 2);

		$k =~ s/%(..)/pack("c",hex($1))/ge;
		$v =~ s/%(..)/pack("c",hex($1))/ge;

		$ret{$k} = $v;
	}

	return \%ret;
}
