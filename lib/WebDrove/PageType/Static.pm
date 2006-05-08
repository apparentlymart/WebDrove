
package WebDrove::PageType::Static;

use strict;

sub constructor {
    my ($page, $ctx, $tablename) = @_;

    my $site = $page->owner;
    my $siteid = $site->siteid;
    my $pageid = $page->pageid;

    my ($pagebody) = $site->db_selectrow_array("SELECT body FROM $tablename WHERE siteid=? and pageid=?",$siteid,$pageid);

    return {
        '_type' => 'Page',
        'content' => $pagebody,
    };
}

1;
