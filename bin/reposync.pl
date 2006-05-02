#!/usr/bin/perl

unless (-d $ENV{'WDHOME'}) { 
    die "\$WDHOME not set.\n";
}

# strip off paths beginning with WDHOME
# (useful if you tab-complete filenames)
$_ =~ s!\Q$ENV{'WDHOME'}\E/?!! foreach (@ARGV);

exit system("$ENV{'WDHOME'}/ext/multicvs.pl", "--conf=$ENV{'WDHOME'}/repos/multicvs.conf", @ARGV);

1;
