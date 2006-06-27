
package WebDrove::PageType::Gallery;

use strict;
use WebDrove::Image;

sub s2_object {
    my ($class, $page, $ctx, $tablename) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Preparing S2 object for gallery page ".$page->pageid);

#	my $pagebody = $class->page_body($page, $tablename);

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my $pagebody = $class->page_body($page, $tablename);
    my $images = $class->get_images($page, $tablename);

	my @s2images = ();

	foreach my $img (@$images) {
		next unless $img->[0] || $img->[1] || $img->[2];

		push @s2images, {
			'_type' => 'Image',
			'width' => $img->[2] ? $img->[2]->width : 0,
			'height' => $img->[2] ? $img->[2]->height : 0,
			'url' => $img->[2] ? $img->[2]->public_url : "",
			'title' => $img->[0],
			'description' => $img->[1],
		};
	}

    return {
        '_type' => 'Page',
        'content' => $pagebody,
        'images' => \@s2images,
    };
}

sub get_content_xml {
	my ($class, $xml, $page, $tablename) = @_;

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my $pagebody = $class->page_body($page, $tablename);
    my $images = $class->get_images($page, $tablename);

	my @xmlimages = ();

	foreach my $img (@$images) {
		my $imageurl = $img->[2] ? $WDConf::ADMINSVC_URL."/sites/$siteid/pages/$pageid/images/".$img->[2]->imageid : "";

		push @xmlimages, $xml->elem("image" => $img->[1],
			$xml->attrib("src" => $imageurl),
			$xml->attrib("title" => $img->[0]),
		);
	}

	return $xml->elem("body" => $pagebody), @xmlimages;
}

sub set_content_xml {
	my ($class, $elem, $page, $tablename) = @_;

	my $log = WebDrove::Logging::get_logger();
	$log->debug("Saving gallery page content");

	my $contentset = $elem->getElementsByTagName("body");
	my $content = $contentset->item(0);
	my $text = $content->getFirstChild() ? $content->getFirstChild()->getData() : "";

	my $imageset = $elem->getElementsByTagName("image");

	my @images;

	for (my $i = 0; $i < $imageset->getLength(); $i++) {
		my $iel = $imageset->item($i);

		my $url = $iel->getAttribute("src");
		my $title = $iel->getAttribute("title");
		my $desc = $iel->getFirstChild() ? $iel->getFirstChild()->getData() : "";
		my $imageid = undef;

		if ($url =~ m!/pages/\d+/images/(\d+)$!) {
			$imageid = $1;
		}

		push @images, [ $title, $desc, $imageid ];
	}

	my $pageid = $page->pageid + 0;

    my $site = $page->owner;
    my $siteid = $site->siteid;

	my $success = $site->db_do("REPLACE INTO $tablename (siteid,pageid,body) VALUES (?,?,?)", $siteid, $pageid, $text);

	$site->db_do("DELETE FROM ${tablename}_image WHERE siteid=? AND pageid=?", $siteid, $pageid);

	my $imgidx = 0;
	foreach my $img (@images) {
		$site->db_do("INSERT INTO ${tablename}_image (siteid,pageid,slot,imageid,imagesiteid,title,description) values (?,?,?,?,?,?,?)", $siteid, $pageid, $imgidx++, $img->[2], $siteid, $img->[0], $img->[1]);
	}

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

	my $sth = $site->db_prepare("SELECT imageid,imagesiteid,title,description FROM ${tablename}_image WHERE siteid=? AND pageid=? ORDER BY slot",$siteid,$pageid);
	$sth->execute($siteid,$pageid);

	my @ret = ();

	while (my ($imageid, $imagesiteid, $title, $desc) = $sth->fetchrow_array()) {

		my $image = undef;

		if ($imageid) {
			my $imagesite = WebDrove::Site->fetch($imagesiteid);
			$image = $imagesite->get_image_by_id($imageid);
		}

		push @ret, [ $title, $desc, $image ];
	}

	return \@ret;

}

1;
