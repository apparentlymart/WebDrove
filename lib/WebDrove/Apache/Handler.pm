
package WebDrove::Apache::Handler;

use strict;
use Apache::Debug;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use WebDrove::Apache::AdminService;
use S2::Runtime::OO;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

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

        $r->content_type("text/html");
        http_header($r);

        my $site = WebDrove::Site->fetch(1);
        my $page = $site->get_page_by_title("About Me");

        my $sitestyle = $site->style();
        my $ctx = $sitestyle->make_context();

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

sub http_header {
    my ($r) = @_;

    return if ($r->notes("webdrove_sent_header"));
    $r->send_http_header();
    $r->notes("webdrove_sent_header", 1);
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
					if (ref($arg) =~ /^(HASH|ARRAY|SCALAR)$/) {
						push @niceargs, ref($arg);
					}
					else {
						push @niceargs, ref($arg)." object";
					}
				}
				else {
					$arg =~ s/\\/\\\\/g;
					$arg =~ s/\"/\\\"/g; #"
					push @niceargs, '"'.$arg.'"';
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

		#print_r_p([ caller($i) ]);
	}

	print "</ul>";

}

package WebDrove::S2::Builtin;

sub ehtml {
    my ($ctx, $s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;#"#
    $s =~ s/'/&#39;/g;
    return $s;
}

sub Page__print_head {
    my ($ctx, $this) = @_;

    $ctx->_print("<style type=\"text/css\">\n");
    $ctx->run("main_stylesheet()");
    $ctx->_print("</style>\n");

}

sub Page__print_body {
    my ($ctx, $this) = @_;

    my $page = $this->{_page};
    my $pctx = $page->s2_context();
    $pctx->set_print(sub { print $_[1]; });
    $pctx->run("Page::print()", $page->s2_object());
}

1;
