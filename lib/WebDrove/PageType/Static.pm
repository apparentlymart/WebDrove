
package WebDrove::PageType::Static;

use strict;

sub s2_object {
    my ($class, $page, $ctx, $tablename) = @_;

#	my $pagebody = $class->page_body($page, $tablename);

    # TEMP: One image per page, until I have time to do this properly
    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my ($pagebody,$imageurl) = $site->db_selectrow_array("SELECT body,imgurl FROM $tablename WHERE siteid=? AND pageid=?",$siteid,$pageid);


    return {
        '_type' => 'Page',
        'content' => $pagebody,
        '_imgurl' => $imageurl,
    };
}

sub get_content_xml {
	my ($class, $xml, $page, $tablename) = @_;

	#my $pagebody = $class->page_body($page, $tablename);

    # TEMP: One image per page, until I have time to do this properly
    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my ($pagebody,$imageurl) = $site->db_selectrow_array("SELECT body,imgurl FROM $tablename WHERE siteid=? AND pageid=?",$siteid,$pageid);


	return $xml->elem("body" => $pagebody), $xml->elem("image" => $xml->attrib("src" => $imageurl));
}

sub set_content_xml {
	my ($class, $elem, $page, $tablename) = @_;

	my $contentset = $elem->getElementsByTagName("body");
	my $content = $contentset->item(0);
	my $text = $content->getFirstChild()->getData();

	my $imageset = $elem->getElementsByTagName("image");
	my $image = $imageset->item(0);
	my $imageurl = $image->getAttribute("src");

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

	my $success = $site->db_do("REPLACE INTO $tablename (siteid,pageid,body,imgurl) VALUES (?,?,?,?)", $siteid, $pageid, $text, $imageurl);

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

1;
