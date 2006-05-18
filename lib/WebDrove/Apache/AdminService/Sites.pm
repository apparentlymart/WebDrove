
package WebDrove::Apache::AdminService::Sites;

use strict;
use WebDrove;
use WebDrove::Apache::Handler;
use WebDrove::Apache::AdminService;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use XML::DOM;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

*redir = \&WebDrove::Apache::AdminService::redir;
*Elem = \&WebDrove::Apache::AdminService::Elem;
*Attrib = \&WebDrove::Apache::AdminService::Attrib;
*xml = \&WebDrove::Apache::AdminService::xml;
*not_found = \&WebDrove::Apache::AdminService::not_found;
*abs_url = \&WebDrove::Apache::AdminService::abs_url;
*xmltime = \&WebDrove::Apache::AdminService::xmltime;

sub service_handler {
    my ($r, $pathbits) = @_;

    my %get = $r->args;

    if (scalar(@$pathbits) == 0) {
        # Doing site discovery
        my $siteid = $get{siteid}+0;
        if ($siteid && WebDrove::Site->fetch($siteid)) {
            return redir($r, "/sites/".$siteid);
        }
        else {
            return not_found($r);
        }
    }

    my $siteid = shift @$pathbits;
    my $site = WebDrove::Site->fetch($siteid) or return not_found($r);

    if (scalar(@$pathbits) == 0) {
		my $defstyle = $site->style;
		my $defstyleurl = abs_url($r, "/sites/$siteid/styles/".$defstyle->styleid);

        return xml($r,
            Elem("site",
            	Attrib("id" => abs_url($r, "/sites/$siteid")),
                Elem("name" => $site->name),
                Elem("links",
	                Elem("styles",
	                	Elem("default" => $defstyleurl),
	                	Elem("list" => abs_url($r, "/sites/$siteid/styles")),
	                ),
	                Elem("pages",
	                	Elem("list" => abs_url($r, "/sites/$siteid/pages")),
	                	Elem("create" => abs_url($r, "/sites/$siteid/pages/add")),
	                ),
	            ),
                Elem("disco",
	                Elem("pages" => abs_url($r, "/sites/$siteid/pages")),
	                Elem("layers" => abs_url($r, "/sites/$siteid/layers")),
				),
            ),
        );

    }

    my $section = shift @$pathbits;

    my $handler = {
    	'styles' => \&styles,
    	'pages' => \&pages,
    	'layers' => \&layers,
    }->{$section};

	return $handler ? $handler->($r, $site, @$pathbits) : not_found($r);
}

sub styles {
	my ($r, $site, $styleid) = @_;

	$styleid += 0;
	my $siteid = $site->siteid;

	if ($styleid) {
		my $style = WebDrove::S2::Style->fetch($site, $styleid);
		my $layers = $style->get_layers();

		return not_found($r) unless $style && $layers;

		return xml($r,
			Elem("style",
				Attrib("id" => abs_url($r, "/sites/$siteid/styles/".$style->styleid)),
				Elem("name" => $style->name),
				Elem("modtime" => xmltime($style->modtime)),
				Elem("layers",
					map {
						Elem("layer",
							Attrib("id" => layer_id_url($r, $_)),
							$_->parent ? Attrib("parent" => layer_id_url($r, $_->parent)) : undef,
							Elem("name" => $_->name),
							Elem("type" => $_->type),
							Elem("links",
								Elem("detail" => layer_id_url($r, $_)),
							),
						);
					} @$layers,
				),
			),
		);
	}

	my $styles = $site->get_styles();

	return xml($r,
		Elem("styles",
			map {
				Elem("style",
					Attrib("id" => abs_url($r, "/sites/$siteid/styles/".$_->styleid)),
					Attrib("local-id" => $_->styleid),
					Elem("name" => $_->name),
					Elem("modtime" => xmltime($_->modtime)),
					Elem("links",
						Elem("detail" => abs_url($r, "/sites/$siteid/styles/".$_->styleid)),
					),
				);
			} @$styles,
		),
	);
}

sub layer_id_url {
	my ($r, $layer) = @_;

	my $layerid = $layer->layerid;

	if ($layer->owner) {
		my $siteid = $layer->owner->siteid;
		return abs_url($r, "/sites/$siteid/layers/$layerid");
	}
	else {
		return abs_url($r, "/s2/layers/$layerid");
	}
}

sub pages {
	my ($r, $site, $pageid) = @_;

	my $siteid = $site->siteid;

	if ($pageid eq 'add') {

		return 405 if $r->method ne 'POST';

		my $clen = $r->header_in("Content-length");
		return 400 if (!$clen);

		my $data = "";
		$r->read($data, $clen);

		my $p = new XML::DOM::Parser();
		my $doc = $p->parse($data);

		my $titleelem = $doc->getDocumentElement()->getElementsByTagName("title");
		$titleelem = $titleelem->item(0);
		return 400 if (! $titleelem);

		my $title = $titleelem->getFirstChild()->getData();
		return 400 unless $title;

		my $page = WebDrove::Page->create_new($site, $title, undef);
		return 500 unless $page;

		$r->header_out("Location" => abs_url($r, "/sites/$siteid/pages/".$page->pageid));
		return 201;
	}

	$pageid += 0;

	if ($pageid) {

		my $page = $site->get_page($pageid);

		return not_found($r) unless $page;

		if ($r->method eq 'GET') {

			my $content = $page->get_content_xml(new WebDrove::Apache::AdminService::XMLBuilder());

			return xml($r,
				Elem("page",
					Attrib("id" => abs_url($r, "/sites/$siteid/pages/".$page->pageid)),
					Attrib("local-id" => $page->pageid),
					Elem("title" => $page->title),
					Elem("type" => $page->type->name),
					Elem("content", $content),
					Elem("links",
						Elem("detail" => abs_url($r, "/sites/$siteid/pages/".$page->pageid)),
					),
				),
			);
		}
		elsif ($r->method eq 'PUT') {
			my $clen = $r->header_in("Content-length");
			return 400 if (!$clen);

			my $data = "";
			$r->read($data, $clen);

			my $p = new XML::DOM::Parser();
			my $doc = $p->parse($data);

			my $titleelem = $doc->getDocumentElement()->getElementsByTagName("title");
			$titleelem = $titleelem->item(0);
			return 400 if (! $titleelem);

			my $contentelem = $doc->getDocumentElement()->getElementsByTagName("content");
			$contentelem = $contentelem->item(0);
			return 400 if (! $contentelem);

			if ($page->title ne 'Home') { # Not allowed to rename the home page
				$page->title($titleelem->getFirstChild()->getData());
			}

			$page->set_content_xml($contentelem);

			$doc->dispose();

			$r->header_out("Location" => abs_url($r, "/sites/$siteid/pages/".$page->pageid));
			return 202;
		}
		elsif ($r->method eq 'DELETE') {
			my $page = $site->get_page($pageid);
			my $success = $site->delete_page($page);
			return $success ? 204 : 500;
		}
		else {
			return 405;
		}

	}

	return 405 if $r->method ne 'GET';

	my %get = $r->args;

	if (%get) {
		my $pageid = $get{localid} + 0;

		return redir($r, "/sites/".$siteid."/pages/".$pageid);
	}
	else {

		my $pages = $site->get_pages();

		return xml($r,
			Elem("pages",
				map {
					Elem("page",
						Attrib("id" => abs_url($r, "/sites/$siteid/pages/".$_->pageid)),
						Attrib("local-id" => $_->pageid),
						Elem("title" => $_->title),
						Elem("type" => $_->type->name),
						Elem("links",
							Elem("detail" => abs_url($r, "/sites/$siteid/pages/".$_->pageid)),
						),
					);
				} @$pages,
			),
		);
	}

}

sub layers {

	my ($r, $site, $pageid) = @_;
	my $siteid = $site->siteid;

	my %get = $r->args;

	if (%get) {

		# FIXME: This interface only supports public layers at present.
		#  Will need to change it later to also include the parent layer's owner
		my $parentlayerid = $get{parentid} ? $get{parentid} + 0 : undef;
		my $type = $get{type} || undef;

		my $parentlay = undef;
		$parentlay = WebDrove::S2::Layer->fetch(undef, $parentlayerid) if (defined($parentlayerid));

		my $layers = WebDrove::S2::get_public_layers($type, $parentlay);

		return xml($r,
			Elem("layers",
				map {
					Elem("layer",
						Attrib("id" => abs_url($r, "/s2/layers/".$_->layerid)),
						Attrib("local-id" => $_->layerid),
						Elem("name" => $_->name),
						Elem("type" => $_->type),
						Elem("uniq" => $_->uniq),
						$_->parent ? Elem("parent" => abs_url($r, "/s2/layers/".$_->parent->layerid)) : undef,
						Elem("links",
							Elem("detail" => abs_url($r, "/s2/layers/".$_->layerid)),
						),
					);
				} @$layers,
			),
		);

	}
	else {
		return not_found($r);
	}

}

1;
