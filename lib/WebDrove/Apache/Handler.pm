
package WebDrove::Apache::Handler;

use strict;
use WebDrove;
use WebDrove::S2;
use WebDrove::DB;
use WebDrove::Site;
use S2::Runtime::OO;
use Apache::Constants qw(:common REDIRECT HTTP_NOT_MODIFIED
                         HTTP_MOVED_PERMANENTLY HTTP_MOVED_TEMPORARILY
                         M_TRACE M_OPTIONS);

use Data::Dumper;

my $s2 = new S2::Runtime::OO;

sub handler {
    my $r = shift;

    $r->handler("perl-script");
    $r->set_handlers(PerlHandler => [ \&test_content ]);
    return OK;
}

sub test_content {
    my $r = shift;

    eval {

        $r->content_type("text/html");
        http_header($r);

        my $site = WebDrove::Site->fetch(1);
        my $page = $site->get_page_by_title("Home");

        my $sitestyle = $site->style();
        my $ctx = $sitestyle->make_context();
        
        my $s2page = {
            _type => 'Page',
            site_title => $site->name,
            page_title => 'Home',
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
    $s =~ s/'/&apos;/g;
    return $s;
}

sub print_r_p {
    my ($val) = @_;
    
    print "<pre>".ehtml(Data::Dumper::Dumper($val))."</pre>";
}

package S2::Builtin;

sub ehtml {
    my ($ctx, $s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}

sub Page__print_head {
    my ($ctx, $this) = @_;
    
}

sub Page__print_body {
    my ($ctx, $this) = @_;

    my $page = $this->{_page};
    my $pctx = $page->s2_context();
    $pctx->set_print(sub { print $_[1]; });
    $pctx->run("Page::print()", $page->s2_object());
}

1;
