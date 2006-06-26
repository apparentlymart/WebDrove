
package WebDrove::Image;

use WebDrove;
use Image::Size;
use File::Path;
use IO::File;
use strict;

# FIXME: Can't instatiate logger here because this gets called before the logger library is loaded! :(
#my $log = WebDrove::Logging::get_logger();

sub fetch {
	my ($class, $site, $imageid) = @_;

    my $meta = $site->db_selectrow_hashref("SELECT * FROM image WHERE siteid=? AND imageid=?", $site->siteid, $imageid);
    return undef unless $meta;
    $meta->{owner} = $site;
    $meta->{page} = $meta->{pageid} ? WebDrove::Page->fetch($site, $meta->{pageid}) : undef;

    return $class->_new_from_meta($meta);
}

sub new {
	my ($class, $site, $page, $data) = @_;

	my $log = WebDrove::Logging::get_logger();

	return undef unless $site && $page;
	return undef unless ref $data eq 'SCALAR';

	$log->debug("Creating new image.");

	my ($w, $h, $type) = Image::Size::imgsize($data);

	if ($type !~ /^(GIF|JPG|PNG)$/i) {
		# Convert the image to JPEG format on the user's behalf

		$log->debug("Image is of type $type. Converting to JPEG.");

		my $gotmagick = eval { require Image::Magick; 1; };
		unless ($gotmagick) {
			$log->error("Image::Magick is not available. Bailing out.");
			return undef;
		}

		my $infh = IO::File->new_tmpfile();
		my $outfh = IO::File->new_tmpfile();

		unless ($infh && $outfh) {
			$log->error("Failed to create temporary files for conversion. Bailing out.");
			return undef;
		}

		binmode($infh);
		binmode($outfh);

		$infh->write($$data, length($$data));
		$infh->seek(0, 0);

		my $image = Image::Magick->new;
		$image->Read(file => $infh);
		$image->Write(file => $outfh, filename => "whatever.jpg");

		$outfh->seek(0, 0);

		$$data = "";
		$outfh->read($$data, 4096, length($$data)) while (! $outfh->eof);

		$outfh->close();
		$infh->close();

		$type = "JPG";

		$log->debug("Conversion succeeded.");

	}

	if ($w > 250 || $h > 250) {

		$log->debug("Image is too large. Scaling down.");

		my $gotmagick = eval { require Image::Magick; 1; };
		unless ($gotmagick) {
			$log->error("Image::Magick is not available. Bailing out.");
			return undef;
		}

		my $infh = IO::File->new_tmpfile();
		my $outfh = IO::File->new_tmpfile();

		unless ($infh && $outfh) {
			$log->error("Failed to create temporary files for resize. Bailing out.");
			return undef;
		}

		binmode($infh);
		binmode($outfh);

		$infh->write($$data, length($$data));
		$infh->seek(0, 0);

		my $image = Image::Magick->new;
		$image->Read(file => $infh);
		$image->Resize(geometry => "250x250");
		$image->Write(file => $outfh, filename => "whatever.jpg");

		$outfh->seek(0, 0);

		$$data = "";
		$outfh->read($$data, 4096, length($$data)) while (! $outfh->eof);

		$outfh->close();
		$infh->close();

		$type = "JPG";

		$log->debug("Resize succeeded.");


	}

	my $basepath = $WDConf::SITE_IMAGE_PATH;

	my $siteid = $site ? $site->siteid : 0;
	my $pageid = $page ? $page->pageid : 0;
	my $imageid = $site->alloc_id("image");

	$log->debug("Allocated imageid $imageid for page $pageid on site $siteid.");

	my $imgpath = sprintf("%08x%08x", $siteid, $imageid);
	$imgpath =~ s!(\w\w)!/$1!g;

    my $madepath = File::Path::mkpath($basepath.$imgpath);
    unless ($madepath) {
	    $log->debug("Failed to create path $basepath$imgpath: $!");
        return undef;
	}

	$imgpath .= ".".lc($type);

	$log->debug("Storing image to $basepath$imgpath");

	my $fh = IO::File->new($basepath.$imgpath, ">");

	unless ($fh) {
		$log->error("Failed to create file $basepath$imgpath: $!");
		return undef;
	}

	print $fh $$data;

	$log->debug("Creating DB row...");
	my $success = $site->db_do("INSERT INTO image (imageid, siteid, pageid, width, height, format) VALUES (?,?,?,?,?,?)", $imageid, $siteid, $pageid, $w, $h, lc($type));

	unless ($success) {
		$log->error("Failed to create DB row for image $imageid for page $pageid on site $siteid");
		return undef;
	}

	$log->debug("Image creation succeeded.");

	return $class->fetch($site, $imageid);
}

sub filename {
	my ($self) = @_;

	my $siteid = $self->owner ? $self->owner->siteid : 0;
	my $imageid = $self->imageid;
	my $format = $self->format;

	my $imgpath = sprintf("%08x%08x", $siteid, $imageid);
	$imgpath =~ s!(\w\w)!/$1!g;
	$imgpath .= ".".lc($format);

	return $WDConf::SITE_IMAGE_PATH.$imgpath;
}

sub list_images_by_site {
	my ($class, $site) = @_;

    my $sth = $site->db_prepare("SELECT * FROM image WHERE siteid=?");
    $sth->execute($site->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $site;
        push @ret, $class->_new_from_meta($meta);
    }

    return \@ret;
}

sub list_images_by_site_and_ids {
	my ($class, $site, @ids) = @_;

	return () unless @ids;

    my $sth = $site->db_prepare("SELECT * FROM image WHERE siteid=? AND imageid IN (".join(',',map{$_+0}@ids).")");
    $sth->execute($site->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $site;
        push @ret, $class->_new_from_meta($meta);
    }

    return \@ret;
}

sub imageid {
	return $_[0]->{imageid};
}

sub owner {
	return $_[0]->{owner};
}

sub page {
	return $_[0]->{page};
}

sub _new_from_meta {
    my ($class, $imagemeta) = @_;

    return bless $imagemeta, $class;
}

sub width {
	return $_[0]->{width}+0;
}
sub height {
	return $_[0]->{height}+0;
}
sub format {
	return $_[0]->{format};
}

sub mime_type {
	my ($self) = @_;
	my $format = $self->format;
	return "image/".($format eq 'jpg' ? 'jpeg' : $format);
}

sub get_data_stream {
	my ($self) = @_;

	my $fh = IO::File->new($self->filename, '<');
	return $fh;
}

sub public_url {
	return '/_/img/u/'.($_[0]->imageid+0).'.'.$_[0]->format;
}

1;
