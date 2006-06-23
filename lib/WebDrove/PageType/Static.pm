
package WebDrove::PageType::Static;

use strict;
use WebDrove::Image;

sub s2_object {
    my ($class, $page, $ctx, $tablename) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Preparing S2 object for static page ".$page->pageid);

#	my $pagebody = $class->page_body($page, $tablename);

    # TEMP: One image per page, until I have time to do this properly
    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my $pagebody = $class->page_body($page, $tablename);
    my $images = $class->get_images($page, $tablename);

	$log->debug("Image is ".$images->[0]);

    return {
        '_type' => 'Page',
        'content' => $pagebody,
        'images' => [
        	map {
        		ref $_ ? {
        			'_type' => 'Image',
        			'width' => $_->width,
        			'height' => $_->height,
        			'alt' => '',
        			'link_url' => '',
        			'url' => $_->public_url,
        		}
        		: {
        			'_type' => 'Image',
        			'width' => 0,
        			'height' => 0,
        			'alt' => '',
        			'link_url' => '',
        			'url' => $_,
        		}
        	} @$images,
        ],
    };
}

sub get_content_xml {
	my ($class, $xml, $page, $tablename) = @_;

    #my $pagebody = $class->page_body($page, $tablename);

    # TEMP: One image per page, until I have time to do this properly
    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my $pagebody = $class->page_body($page, $tablename);
    my $images = $class->get_images($page, $tablename);
    my $image = $images->[0] ? $images->[0] : "";

    my $imageurl = ref $image ? $WDConf::ADMINSVC_URL."/sites/$siteid/pages/$pageid/images/".$image->imageid : $image;

	return $xml->elem("body" => $pagebody), $xml->elem("image", $xml->attrib("src" => $imageurl));
}

sub set_content_xml {
	my ($class, $elem, $page, $tablename) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Saving static page content");

	my $contentset = $elem->getElementsByTagName("body");
	my $content = $contentset->item(0);
	my $text = $content->getFirstChild() ? $content->getFirstChild()->getData() : "";

	my $imageset = $elem->getElementsByTagName("image");
	my $imageurl = $imageset->item(0)->getAttribute("src");

	my $pageid = $page->pageid + 0;

	my $imageid = undef;
	my $imagesiteid = undef;
	my $imgurl = undef;


	if ($imageurl) {

		$log->debug("Image URL is $imageurl");

		# TRICKERY: Recognise if it's a webservice URL pointing at a
		# WebDrove-hosted image or an external image and store differently.
		if (substr($imageurl,0,length($WDConf::ADMINSVC_URL)) eq $WDConf::ADMINSVC_URL) {
			# It's one of our internal image URLs.
			if ($imageurl =~ m!/pages/\d+/images/(\d+)$!) {
				$imageid = $1;
				$imagesiteid = $page->owner->siteid;
				$log->debug("Using local image $imageid owned by $imagesiteid.");
			}
			else {
				$log->debug("This image URL makes no sense to me.");
			}
		}
		else {
			$imgurl = $imageurl;
			$log->debug("Using this URL as an external image URL directly.");
		}
	}
	else {
		$log->debug("No image selected.");
	}

    my $site = $page->owner;
    my $siteid = $site->siteid;

	my $success = $site->db_do("REPLACE INTO $tablename (siteid,pageid,body,imgurl,imageid,imagesiteid) VALUES (?,?,?,?,?,?)", $siteid, $pageid, $text, $imgurl, $imageid, $imagesiteid);

	$log->debug($success ? "Page save succeeded." : "Page save failed.");

	return $success;
}

sub page_body {
	my ($class, $page, $tablename) = @_;

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my ($pagebody) = $site->db_selectrow_array("SELECT body FROM $tablename WHERE siteid=? AND pageid=?",$siteid,$pageid);

	return $pagebody;
}

sub get_images {
	my ($class, $page, $tablename) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Fetching images");

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

	my ($imageid, $imagesiteid, $imgurl) = $site->db_selectrow_array("SELECT imageid,imagesiteid,imgurl FROM ${tablename} WHERE siteid=? AND pageid=?",$siteid,$pageid);

	return [] unless $imageid || $imgurl;

	if ($imageid) {
		$log->debug("This page has a local image");
		my $imagesite = WebDrove::Site->fetch($imagesiteid);
		my $image = $imagesite->get_image_by_id($imageid);
		unless ($image) {
			$log->debug("Failed to load image $imageid");
			return [];
		}
		return [ $image ];
	}
	elsif ($imgurl) {
		$log->debug("This page has an external image");
		return [ $imgurl ];
	}

}

1;
