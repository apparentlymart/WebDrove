
package WebDrove::PageType::Static;

use strict;
use WebDrove::Image;

sub s2_object {
    my ($class, $page, $ctx, $tablename) = @_;

#	my $pagebody = $class->page_body($page, $tablename);

    # TEMP: One image per page, until I have time to do this properly
    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my $pagebody = $class->page_body($page, $tablename);
    my $images = $class->get_images($page, $tablename);

    return {
        '_type' => 'Page',
        'content' => $pagebody,
        'images' => [ map { {
        	'_type' => 'Image',
        	'width' => $_->width,
        	'height' => $_->height,
        	'alt' => '',
        	'link_url' => '',
        	'url' => '/_/img/u/'.($_->imageid+0).'.'.$_->format,
        } } @$images ],
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

	return $xml->elem("body" => $pagebody);
}

sub set_content_xml {
	my ($class, $elem, $page, $tablename) = @_;

	my $contentset = $elem->getElementsByTagName("body");
	my $content = $contentset->item(0);
	my $text = $content->getFirstChild()->getData();

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

	my $success = $site->db_do("REPLACE INTO $tablename (siteid,pageid,body) VALUES (?,?,?)", $siteid, $pageid, $text);

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

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

	my ($imageid, $imagesiteid) = $site->db_selectrow_array("SELECT imageid,imagesiteid FROM ${tablename} WHERE siteid=? AND pageid=?",$siteid,$pageid);

	return [] unless $imageid;

	my $imagesite = WebDrove::Site->fetch($imagesiteid);
	return [ $imagesite->get_image_by_id($imageid) ];
}

1;
