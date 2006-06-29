
package WebDrove::ImageManipulation;

# This is just a wrapper around PerlMagick to handle
# the delay-loading and the transforming to and from
# scalarrefs.

# We delay-load *::Magick because it's quite a heavy library.
sub _load_magick {
	my $gotmagick = eval { require Graphics::Magick; 1; };
	unless ($gotmagick) {
		$log->error("Graphics::Magick is not available.");
		return undef;
	}
	return 1;
}

sub convert {
	my ($dataref, $format) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Doing image conversion to $format.");

	return undef unless _load_magick();

	my $img = Image::Magick->new();
	$img->BlobToImage($$dataref);
	($$dataref) = $img->ImageToBlob(magick => $format);

	if ($$dataref eq '') {
		$log->error("Image conversion to $format failed.");
	}

	$log->debug("Image conversion succeeded.");

	return $$dataref ne '';
}

sub resize {
	my ($dataref, $geometry) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Doing image resize to $geometry.");

	return undef unless _load_magick();

	my $img = Image::Magick->new();
	$img->BlobToImage($$dataref);
	$img->Resize(geometry => $geometry);
	($$dataref) = $img->ImageToBlob();

	if ($$dataref eq '') {
		$log->error("Image resize to $geometry failed.");
	}

	$log->debug("Image resize succeeded.");

	return $$dataref ne '';
}

1;
