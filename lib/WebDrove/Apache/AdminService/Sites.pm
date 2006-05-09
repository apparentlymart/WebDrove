
package WebDrove::Apache::AdminService::Sites;

use strict;
use WebDrove;
use WebDrove::Apache::Handler;
use WebDrove::Apache::AdminService;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
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
	                ),
	            ),
            ),
        );

    }

    my $section = shift @$pathbits;

    my $handler = {
    	'styles' => \&styles,
    	'pages' => \&pages,
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

	return xml($r,
		Elem("pages",

		),
	);

}


1;
