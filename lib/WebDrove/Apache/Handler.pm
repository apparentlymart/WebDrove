
package WebDrove::Apache::Handler;

use strict;
use Apache::Debug;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use WebDrove::Apache::Request;
use WebDrove::Apache::AdminService;
use S2::Runtime::OO;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

my $log = WebDrove::Logging::get_logger();

$SIG{__DIE__} = sub {
    my $r = Apache->request;
    my @err = shift;

    $r->status_line("500 System Error");
    $r->content_type("text/html");
    http_header($r);
    print "<h1>System Error</h1>\n";
    print "<p>".ehtml(join('',@err))."</p>";

    pretty_stack_trace($r, 1);

    Apache::exit();
};

use Data::Dumper;

my $s2 = new S2::Runtime::OO;

sub handler {
    my $r = shift;

    $r->handler("perl-script");
    $r->set_handlers(PerlHandler => [ \&response_handler ]);

    return OK;
}

sub response_handler {
    my $r = shift;

    my $dir_mode = $r->dir_config('webdrove_mode');

    if ($dir_mode eq 'passthrough') {
        return DECLINED;
    }

    if ($dir_mode eq 'adminservice') {
        return WebDrove::Apache::AdminService::handler($r);
    }

    return site_content($r);
}

sub site_content {
    my $r = shift;

    eval {

        die "No SITE_SELECTOR is configured; can't continue!" if (ref $WDConf::SITE_SELECTOR ne 'CODE');

        my $siteid = $WDConf::SITE_SELECTOR->($r);
        return http_404_error($r, "Site selector returned undef") unless ($siteid);

        my $site = WebDrove::Site->fetch($siteid);
        return http_404_error($r, "Can't load site $siteid") unless ($site);

        my $uri = $r->uri;

        if ($uri =~ m!^/_/!) { # Special resource URL
        	return site_media($r, $site, substr($uri, 3));
        }

        my $pagename = undef;
        my @pathbits = ();

        if ($uri eq '/') {
            $pagename = "Home"; # FIXME: Don't hardcode "Home" as the homepage
        }
        elsif ($uri !~ m!/$!) {
        	return 404;
        }
        elsif ($uri =~ m!^/([^/]+)/(.*)$!) {
            $pagename = $1;
            my $rest = $2;
            return http_404_error($r, "The page name 'Home' is reserved") if $pagename eq 'Home';
            $pagename =~ s/\+/ /g;
            $pagename =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("c",hex($1))/eg;
			@pathbits = split(m!/!, $rest) if $rest;
        }
        else {
            return http_404_error($r, "Nonsense URI");
        }

        my $page = $site->get_page_by_title($pagename);
        return http_404_error($r, "Can't find page for name '$pagename'") unless $page;

		my $nav = new WebDrove::Apache::Request($r, $site);

        my $s2pagebody = $page->s2_object(\@pathbits, $nav);
        return 404 unless $s2pagebody;

        $r->content_type("text/html");
        http_header($r);

        my $sitestyle = $site->style();
        my $ctx = $sitestyle->make_context();
        $ctx->do_stack_trace(1);

        my $pages = $site->get_pages();
        my @s2pages = map {
            {
                _type => 'Link',
                caption => $_->title,
                url => $_->url,
                active => $_->equals($page),
                current => $_->equals($page),
            }
        } @$pages;

        my $s2page = {
            _type => 'Page',
            site_title => $site->name,
            page_title => $page->title,
            nav => \@s2pages,
            _page => $page,
            _pathbits => \@pathbits,
            _s2pagebody => $s2pagebody,
            _site => $site,
        };

        $ctx->set_print(sub { print $_[1]; });
        $ctx->run("Page::print()", $s2page);

    };
    if ($@) {
        $r->content_type("text/html");
        http_header($r);
        print "<pre>".ehtml($@)."</pre>";
    }

    return OK;
}

sub site_media {
	my ($r, $site, $uri) = @_;

	if ($uri eq 'stylesheet') {
        my $sitestyle = $site->style();
        my $ctx = $sitestyle->make_context();
        $ctx->do_stack_trace(1);
		$r->content_type("text/css");
		http_header($r);
		$ctx->set_print(sub { print $_[1]; });
		$ctx->run("main_stylesheet()");
		return 200;

	}
	elsif ($uri =~ m!^img/u/(\d+)([sml])\.([jgp][pin][gf])$!) {
		my $imageid = $1+0;
		my $size = $2;
		my $format = $3;
		
		my $image = $site->get_image_by_id($imageid);
		return 404 unless ref $image;
		return 404 unless $image->format eq $format;

		$r->content_type($image->mime_type);
		http_header($r);
		my $fh = $image->get_data_stream($size);
		$r->send_fd($fh);

		return 200;
	}
	else {
		return 404;
	}
}

sub http_header {
    my ($r) = @_;

    return if ($r->notes("webdrove_sent_header"));
    $r->send_http_header();
    $r->notes("webdrove_sent_header", 1);
}

sub http_404_error {
    my ($r, $reason) = @_;
    $r->status(404);
    $r->content_type("text/html");
    http_header($r);
    print "<p>Page not found.</p>";
    $log->error("404 Not Found for ".$r->uri.": ".$reason);
    return 200;
}

sub ehtml {
    my ($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;#"#
    $s =~ s/'/&#39;/g;
    return $s;
}

sub print_r_p {
    my ($val) = @_;

    print "<pre>".ehtml(Data::Dumper::Dumper($val))."</pre>";
}

sub pretty_stack_trace {
    my ($r, $skip) = @_;
    $skip += 1;

    package DB; # HACK: If we call caller() from this package, Perl does magic things

    *DB::ehtml = \&WebDrove::Apache::Handler::ehtml;

    print "<ul>";

    for (my $i = $skip; caller($i); $i++) {
        my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require) = caller($i);

        print "<li><strong>".ehtml($subroutine)."</strong>(";

        if ($hasargs) {
            my @niceargs = ();
            foreach my $arg (@DB::args) {
                if (ref $arg) {
                    if (ref($arg) eq 'HASH' && $arg->{_type}) {
                        push @niceargs, "S2 ".($arg->{_isnull} ? "null " : "").$arg->{_type}." object";
                    }
                    elsif (ref($arg) =~ /^(HASH|ARRAY|SCALAR|CODE)$/) {
                        push @niceargs, lc(ref($arg))."ref";
                    }
                    else {
                        push @niceargs, ref($arg)." object";
                    }
                }
                elsif (! defined($arg)) {
                    push @niceargs, "undef";
                }
                else {
                    my $a = $arg;
                    $a =~ s/\\/\\\\/g;
                    $a =~ s/\"/\\\"/g; #"
                    push @niceargs, '"'.$a.'"';
                }
            }
            print join(", ", map({ehtml($_)} @niceargs));
        }

        print ")<div style='font-size: 0.75em;'>called ";

        if ($line) {
            print "at <strong>".ehtml($filename)."</strong> line ".ehtml($line);
        }
        else {
            print "from another universe";
        }

        print "</div></li>";
    }

    print "</ul>";

}

1;
