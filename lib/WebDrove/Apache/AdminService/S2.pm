
package WebDrove::Apache::AdminService::S2;

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
    my $section = shift @$pathbits;

    my $handler = {
    	'styles' => \&styles,
    	'layers' => \&layers,
    }->{$section};

	return $handler ? $handler->($r, @$pathbits) : not_found($r);
}

sub layers {
	my ($r, $layerid, $mode) = @_;

	my %get = $r->args;

	if (defined($layerid)) {

		my $layer = WebDrove::S2::Layer->fetch(undef, $layerid);

		return xml($r,
			Elem("layer",
				Attrib("id" => abs_url($r, "/s2/layers/".$layer->layerid)),
				Attrib("local-id" => $layer->layerid),
				Elem("name" => $layer->name),
				Elem("type" => $layer->type),
				Elem("uniq" => $layer->uniq),
				$layer->parent ? Elem("parent" => abs_url($r, "/s2/layers/".$layer->parent->layerid)) : undef,
				Elem("links",
					Elem("detail" => abs_url($r, "/s2/layers/".$layer->layerid)),
				),
			),
		);


	}
	else {

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

}

sub styles {
	my ($r, @pathbits) = @_;

}

1;
