
package WebDrove::Image;

use WebDrove;
use WebDrove::ImageManipulation;
use Image::Size;
use File::Path;
use IO::File;
use strict;

$Image::Size::NO_CACHE = 1;

# FIXME: Can't instatiate logger here because this gets called before the logger library is loaded! :(
#my $log = WebDrove::Logging::get_logger();

sub fetch {
	my ($class, $site, $imageid) = @_;

	my $log = WebDrove::Logging::get_logger();
	
    my $sth = $site->db_prepare("SELECT * FROM image WHERE siteid=? AND imageid=?");
    $sth->execute($site->siteid, $imageid);
    
    my %sizes = {};
    while (my $meta = $sth->fetchrow_hashref()) {
	$sizes{$meta->{size}} = $meta;
	$log->debug("Image for ".$meta->{size}." ".$sizes{$meta->{size}}{"width"}."x".$sizes{$meta->{size}}{"height"});
    }
    
    $sizes{"m"}{sizes} = \%sizes;
    my $meta = $sizes{"m"};
    
    $meta->{owner} = $site;
    $meta->{page} = $meta->{pageid} ? WebDrove::Page->fetch($site, $meta->{pageid}) : undef;

	$log->debug("Set default to ".$meta->{"width"}." x ".$meta->{"height"});
    return $class->_new_from_meta($meta);
}

sub new {
	my ($class, $site, $page, $data) = @_;

	my $log = WebDrove::Logging::get_logger();

	return undef unless $site && $page;
	return undef unless ref $data eq 'SCALAR';

	my $basepath = $WDConf::SITE_IMAGE_PATH;

	my $siteid = $site ? $site->siteid : 0;
	my $pageid = $page ? $page->pageid : 0;
	my $imageid = $site->alloc_id("image");

	$log->debug("Allocated imageid $imageid for page $pageid on site $siteid.");

	my ($w, $h, $type);
	foreach(qw(l m s))
	{
		($w, $h, $type) = $class->get_scaled_image($site, $page, $data, $_);
		return undef unless $data;
		my $saved = $class->save_image($site, $page, $data, $_, $siteid, $pageid, $imageid, $w, $h, $type);
		return undef unless $saved;
	}
	
	return $class->fetch($site, $imageid);
}

sub save_image
{
	my ($class, $site, $page, $data, $size, $siteid, $pageid, $imageid, $w, $h, $type) = @_;
	
	my $log = WebDrove::Logging::get_logger();
	
	my $basepath = $WDConf::SITE_IMAGE_PATH;
	
	my $imgpath = sprintf("%08x%08x", $siteid, $imageid);
	$imgpath =~ s!(\w\w)!/$1!g;

	my $madepath = File::Path::mkpath($basepath.$imgpath);
	unless (-d $basepath.$imgpath) {
		$log->debug("Failed to create path $basepath$imgpath: $!");
		return undef;
	}
	
	if(lc($size) eq "s" || lc($size) eq "l") { $imgpath.="-".lc($size); }
	
	$imgpath .= ".".lc($type);

	$log->debug("Storing image to $basepath$imgpath");

	my $fh = IO::File->new($basepath.$imgpath, ">");

	unless ($fh) {
		$log->error("Failed to create file $basepath$imgpath: $!");
		return undef;
	}

	print $fh $$data;

	$log->debug("Creating DB row...");
	my $success = $site->db_do("INSERT INTO image (imageid, siteid, pageid, size, width, height, format) VALUES (?,?,?,?,?,?,?)", $imageid, $siteid, $pageid, lc($size), $w, $h, lc($type));

	unless ($success) {
		$log->error("Failed to create DB row for image $imageid for page $pageid on site $siteid");
		return undef;
	}

	$log->debug("Image creation succeeded.");

	return 1;
}

sub get_scaled_image
{
	my ($class, $site, $page, $data, $size) = @_;

	my $log = WebDrove::Logging::get_logger();

	return undef unless $site && $page;
	return undef unless ref $data eq 'SCALAR';

	$log->debug("Creating new image.");

	my ($w, $h, $type) = Image::Size::imgsize($data);

	$log->debug("Image is a $w x $h $type.");
	
	my ($nw, $nh) = @{{
		"s" => [100,100], "m" => [250, 250], "l" => [700, 700]
	}->{$size}};
	
	
	if ($type !~ /^(GIF|JPG|PNG)$/i) {
		# Convert the image to JPEG format on the user's behalf

		$log->debug("Image is of type $type. Converting to JPEG.");

		return undef unless WebDrove::ImageManipulation::convert($data, "jpg");
		$type = "JPG";

		$log->debug("Conversion succeeded.");

	}
	
	

	if ($w > $nw || $h > $nh) {

		$log->debug("Image is too large. Scaling down.");

		return undef unless WebDrove::ImageManipulation::resize($data, "${nw}x${nh}");

		($w, $h, $type) = Image::Size::imgsize($data);

		$log->debug("Resize succeeded. New size is $w x $h");

	}
	
	return($w, $h, $type);

}

sub filename {
	my ($self, $size) = @_;

	$size ||= "m";

	my $siteid = $self->owner ? $self->owner->siteid : 0;
	my $imageid = $self->imageid;
	my $format = $self->format;

	my $imgpath = sprintf("%08x%08x", $siteid, $imageid);
	$imgpath =~ s!(\w\w)!/$1!g;
	
	if(lc($size) eq "s" || lc($size) eq "l") { $imgpath.="-".lc($size); }
	
	
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
	my ($self, $size) = @_;
	$size ||= "m";
	return $self->{sizes}{$size}{width}+0;
}
sub height {
	my ($self, $size) = @_;
	$size ||= "m";
	return $self->{sizes}{$size}{height}+0;
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
	my ($self, $size) = @_;

	my $fh = IO::File->new($self->filename($size), '<');
	return $fh;
}

sub public_url {
	my ($self, $size) = @_;
	$size ||= "m";
	return '/_/img/u/'.($self->imageid+0).$size.'.'.$self->format;
}

1;
