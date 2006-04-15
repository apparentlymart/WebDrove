
package WebDrove::PageType;

use WebDrove;
use WebDrove::DB;
use strict;

sub fetch {
    my ($class, $typeid) = @_;

    my $self = {
        typeid => $typeid,
        name => undef,
        displayname => undef,
        constructor => undef,
    };

    return bless $self, $class;
}

1;
