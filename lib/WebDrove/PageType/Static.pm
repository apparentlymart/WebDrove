
package WebDrove::PageType::Static;

use strict;

sub s2_object {
    my ($class, $page, $ctx, $tablename) = @_;

	my $pagebody = $class->page_body($page, $tablename);

    return {
        '_type' => 'Page',
        'content' => $pagebody,
    };
}

sub get_content_xml {
	my ($class, $xml, $page, $tablename) = @_;

	my $pagebody = $class->page_body($page, $tablename);

	return $xml->elem("body" => $pagebody);
}

sub set_content_xml {
	my ($class, $elem, $page, $tablename) = @_;


}

sub page_body {
	my ($class, $page, $tablename) = @_;

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my ($pagebody) = $site->db_selectrow_array("SELECT body FROM $tablename WHERE siteid=? and pageid=?",$siteid,$pageid);

	return $pagebody;
}

1;
