
package WebDrove::Site;

use WebDrove;
use WebDrove::DB;
use WebDrove::Page;
use WebDrove::S2::Style;
use strict;

sub fetch {
    my ($class, $siteid) = @_;

    # We use a writer here even though we're reading to ensure
    # we get fresh data, since this table is quite fundamental.
    my $dbh = WebDrove::DB::get_db_writer();

    my $site = $dbh->selectrow_hashref("SELECT * FROM site WHERE siteid = ?", undef, $siteid);

    return undef unless $site && %$site;
    return bless $site, $class;
}

sub name {
    return $_[0]->{name};
}

sub get_db_reader {
    return WebDrove::DB::get_db_reader();
}

sub get_db_writer {
    return WebDrove::DB::get_db_writer();
}

sub db_selectrow_hashref {
    my ($self, $query, @args) = @_;

    my $dbh = $self->get_db_reader();
    return $dbh->selectrow_hashref($query, undef, @args);
}

sub db_selectrow_array {
    my ($self, $query, @args) = @_;

    my $dbh = $self->get_db_reader();
    return $dbh->selectrow_array($query, undef, @args);
}

sub db_do {
    my ($self, $query, @args) = @_;

    my $dbh = $self->get_db_writer();
    return $dbh->do($query, undef, @args);
}

sub db_prepare {
    my ($self, $query) = @_;

    my $dbh = $self->get_db_reader();
    return $dbh->prepare($query);
}

sub db_prepare_write {
    my ($self, $query) = @_;

    my $dbh = $self->get_db_writer();
    return $dbh->prepare($query);
}

sub siteid {
    return ($_[0]->{siteid} + 0) || die "Corrupted WebDrove::Site object (no siteid?!)";
}

sub alloc_id {
    my ($self, $area) = @_;

    my $siteid = $self->siteid;

    return WebDrove::DB::alloc_id($self->get_db_writer(), $siteid, $area);

}

sub style {
    my ($self) = @_;

    return $self->{style} if defined $self->{style};

    return $self->{style} = WebDrove::S2::Style->fetch($self, $self->{styleid});
}

sub get_styles {
	my ($self) = @_;

	return WebDrove::S2::Style->get_site_styles($self);
}

sub get_page {
    my ($self, $pageid) = @_;

    my $meta = $self->db_selectrow_hashref("SELECT * FROM page WHERE siteid=? AND pageid=?", $self->siteid, $pageid);
    return undef unless $meta;
    $meta->{owner} = $self;

    return new WebDrove::Page($meta);
}

sub get_page_by_title {
    my ($self, $title) = @_;

    my $meta = $self->db_selectrow_hashref("SELECT * FROM page WHERE siteid=? AND title=?", $self->siteid, $title);
    return undef unless $meta;
    $meta->{owner} = $self;

    return new WebDrove::Page($meta);
}

sub get_pages {
    my ($self) = @_;

    my $ooify = sub {
        my ($meta) = @_;

    };

    my $sth = $self->db_prepare("SELECT * FROM page WHERE siteid=? ORDER BY sort");
    $sth->execute($self->siteid);

    my @ret = ();
    while (my $meta = $sth->fetchrow_hashref()) {
        $meta->{owner} = $self;
        push @ret, new WebDrove::Page($meta);
    }

    return \@ret;
}

sub equals {
    return $_[0]->siteid eq $_[1]->siteid;
}

1;
