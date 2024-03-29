
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

my $log = WebDrove::Logging::get_logger();

*redir = \&WebDrove::Apache::AdminService::redir;
*Elem = \&WebDrove::Apache::AdminService::Elem;
*Attrib = \&WebDrove::Apache::AdminService::Attrib;
*xml = \&WebDrove::Apache::AdminService::xml;
*not_found = \&WebDrove::Apache::AdminService::not_found;
*abs_url = \&WebDrove::Apache::AdminService::abs_url;
*xmltime = \&WebDrove::Apache::AdminService::xmltime;
*logged_error_response = \&WebDrove::Apache::AdminService::logged_error_response;

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

	if ($pathbits->[0] eq 'create') {
		return 405 unless $r->method eq 'POST';

		my $clen = $r->header_in("Content-length");
		return 400 if (!$clen);

		my $data = "";
		$r->read($data, $clen);

		my $p = new XML::DOM::Parser();
		my $doc = $p->parse($data);

		my $nameelem = $doc->getDocumentElement()->getElementsByTagName("name");
		$nameelem = $nameelem->item(0);
		return 400 if (! $nameelem);

		my $name = $nameelem->getFirstChild()->getData();
		return 400 unless $name;

		my $site = WebDrove::Site->new($name);
		return 500 unless $site;

		my $siteid = $site->siteid;
		$r->header_out("Location" => abs_url($r, "/sites/".$siteid));

		#my $defstyle = $site->style;
		#my $defstyleurl = abs_url($r, "/sites/$siteid/styles/".$defstyle->styleid);

        return xml($r,
            Elem("site",
            	Attrib("id" => abs_url($r, "/sites/$siteid")),
            	Attrib("local-id" => $siteid),
                Elem("name" => $site->name),
                Elem("links",
	                Elem("styles",
	                	#Elem("default" => $defstyleurl),
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
    my $siteid = shift @$pathbits;
    my $site = WebDrove::Site->fetch($siteid) or return not_found($r);

    if (scalar(@$pathbits) == 0) {
		my $defstyle = $site->style;
		my $defstyleurl = abs_url($r, "/sites/$siteid/styles/".$defstyle->styleid);

        return xml($r,
            Elem("site",
            	Attrib("id" => abs_url($r, "/sites/$siteid")),
            	Attrib("local-id" => $siteid),
                Elem("name" => $site->name),
                Elem("links",
	                Elem("styles",
	                	Elem("default" => $defstyleurl),
	                	Elem("list" => abs_url($r, "/sites/$siteid/styles")),
	                ),
	                Elem("pages",
	                	Elem("list" => abs_url($r, "/sites/$siteid/pages")),
	                	Elem("create" => abs_url($r, "/sites/$siteid/pages/add")),
	                	Elem("reorder" => abs_url($r, "/sites/$siteid/pages/reorder")),
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

		# HACK: Temporarily have a webservice call that just sets the layout,
		#   until there's time to do this properly.
		if ($_[3] eq 'setlayout' && $r->method eq 'POST') {
			my %get = $r->args;
			return 500 unless $get{layerid};
			my $newlayer = WebDrove::S2::Layer->fetch(undef, $get{layerid}+0);
			return 500 unless $newlayer;
			$style->set_layer("layout", $newlayer);
			return 204;
		}

		my $layers = $style->get_layers();

		return not_found($r) unless $style && $layers;

		return xml($r,
			Elem("style",
				Attrib("id" => abs_url($r, "/sites/$siteid/styles/".$style->styleid)),
				Attrib("local-id" => $style->styleid),
				Elem("name" => $style->name),
				Elem("modtime" => xmltime($style->modtime)),
				Elem("layers",
					map {
						Elem("layer",
							Attrib("id" => layer_id_url($r, $_)),
							Attrib("local-id" => $_->layerid),
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
	my ($r, $site, $pageid, $mode, @extra) = @_;

	my $siteid = $site->siteid;

	if ($pageid eq 'add') {

		$log->debug("Creating new page for site ".$site->siteid);

		return logged_error_response(405, "Invalid request method ".$r->method." for page add request") if $r->method ne 'POST';

		my $clen = $r->header_in("Content-length");
		return logged_error_response(400, "Missing content length in page add request") if (!$clen);

		my $data = "";
		$r->read($data, $clen);

		my $p = new XML::DOM::Parser();
		my $doc = $p->parse($data);

		my $titleelem = $doc->getDocumentElement()->getElementsByTagName("title");
		$titleelem = $titleelem->item(0);
		return logged_error_response(400, "Missing title element in page add request") if (! $titleelem);

		my $typeelem = $doc->getDocumentElement()->getElementsByTagName("type");
		$typeelem = $typeelem->item(0);
		logged_error_response(400, "Missing type element in page add request") if (! $typeelem);

		my $title = $titleelem->getFirstChild()->getData();
		return logged_error_response(400, "Empty title in page add request") unless $title;

		my $type = $typeelem->getFirstChild()->getData();
		return logged_error_response(400, "Empty type name in page add request") unless $type;

		my $page = WebDrove::Page->new($site, $title, $type);
		return logged_error_response(500, "Page creation failed") unless $page;

		$r->header_out("Location" => abs_url($r, "/sites/$siteid/pages/".$page->pageid));


		$log->debug("Created new page ".$page->pageid." for site ".$site->siteid);
		return 201;
	}
	elsif ($pageid eq 'reorder') {

		$log->debug("Reordering pages for site ".$site->siteid);

		return logged_error_response(405, "Invalid request method ".$r->method." for page reorder request") if $r->method ne 'POST';

		my $clen = $r->header_in("Content-length");
		return logged_error_response(400, "Missing content length in page add request") if (!$clen);

		my $data = "";
		$r->read($data, $clen);

		my $p = new XML::DOM::Parser();
		my $doc = $p->parse($data);

		my $pages = $doc->getDocumentElement()->getElementsByTagName("page");

		my @pages = ();

		for (my $i = 0; $i < $pages->getLength; $i++) {
			my $pageelem = $pages->item($i);
			push @pages, $site->get_page($pageelem->getAttribute("localid"));
		}

		$site->set_page_order(\@pages);

		return 202;

	}

	$pageid += 0;

	if ($pageid) {

		my $page = $site->get_page($pageid);

		return not_found($r) unless $page;

		if ($r->method eq 'GET') {

			if ($mode eq 'layouts') {

				my $layouts = $page->s2_layouts();

				return xml($r,
					Elem("layers",
						map {
							Elem("layer",
								Attrib("id" => layer_id_url($r, $_)),
								Attrib("local-id" => $_->layerid),
								$_->parent ? Attrib("parent" => layer_id_url($r, $_->parent)) : undef,
								Elem("name" => $_->name),
								Elem("type" => $_->type),
								Elem("links",
									Elem("detail" => layer_id_url($r, $_)),
								),
							),
						} @$layouts,
					),
				);

			}
			elsif ($mode eq 'images' && scalar(@extra) == 1) {

				my $imageid = $extra[0] + 0;
				my $image = WebDrove::Image->fetch($site, $imageid);

				return 404 unless $image;

				$r->content_type($image->mime_type);

				WebDrove::Apache::Handler::http_header($r);
				my $fh = $image->get_data_stream;
				$r->send_fd($fh);
				$fh->close();

				return 200;

			}
			elsif (! defined($mode)) {

				my @content = $page->get_content_xml(new WebDrove::Apache::AdminService::XMLBuilder());

				return xml($r,
					Elem("page",
						Attrib("id" => abs_url($r, "/sites/$siteid/pages/".$page->pageid)),
						Attrib("local-id" => $page->pageid),
						Elem("title" => $page->title),
						Elem("type" => $page->type->name),
						Elem("content", @content),
						Elem("links",
							Elem("detail" => abs_url($r, "/sites/$siteid/pages/".$page->pageid)),
							Elem("layouts" => abs_url($r, "/sites/$siteid/pages/".$page->pageid."/layouts")),
							Elem("style" => abs_url($r, "/sites/$siteid/styles/".$page->style->styleid)),
							Elem("images",
								Elem("add" => abs_url($r, "/sites/$siteid/pages/".$page->pageid."/images/add")),
								Elem("disco" => abs_url($r, "/sites/$siteid/pages/".$page->pageid."/images")),
								Elem("list" => abs_url($r, "/sites/$siteid/pages/".$page->pageid."/images")),
							),
						),
					),
				);

			}
			else {
				return logged_error_response(404, "Unknown page sub-section $mode");
			}
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
		elsif ($r->method eq 'POST') {

			my $clen = $r->header_in("Content-length");
			return 400 if (!$clen);

			my $data = "";
			$r->read($data, $clen);

			if ($mode eq 'images' && $extra[0] eq 'add') {
				my $image = WebDrove::Image->new($site, $page, \$data);

				if (defined($image)) {
					$r->header_out("Location" => abs_url($r, "/sites/$siteid/pages/".$page->pageid."/images/".$image->imageid));
					return 201;
				}
				else {
					return 500;
				}
			}
			else {
				return 405;
			}

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
