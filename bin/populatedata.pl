#!/usr/bin/perl

# Tool to read both core and site-specific resources from files
# on disk and load them into the database based on configuration.

use strict;
use lib "$ENV{WDHOME}/lib";
use WebDrove;

use Getopt::Long;
use File::Path ();
use File::Basename ();
use WebDrove::S2;
use Data::Dumper;
use S2::Compiler;
use S2::Runtime::OO;

sub task($&);
sub step($);
sub begin_task($);
sub end_task();
sub warning($);
sub fail($);

fail("WDHOME not correctly set") unless -d $ENV{WDHOME};
chdir($ENV{WDHOME});

my %s2layer = ();
my $taskdepth = 0;

task "Populating S2 layers", sub {

    # For now this just recompiles all layers every time.
    # It might be nice later to make it only recompile layers that have changed.

    my %s2ck = ();
    my %s2kids = ();
    my %layertype = map { $_ => 1 } qw(core i18nc layout i18n theme user);
    my @layers = ();

    # Parse the manifest file
    open(IN, "local/s2layers.dat") or fail("Couldn't open layer manifest local/s2layers.dat");

    # TODO: Refactor this a bit so the file can include other files, allowing sites
    # to make use of packages of layers all in one go.

    my $line = 1;
    while (my $l = <IN>) {
        chomp $l;

        $l =~ s/#.*//;
        $l =~ s/^\s+//;
        $l =~ s/\s+$//;
        my @bits = split(/\s+/, $l);

        fail("Syntax error at line $line") if (scalar(@bits) > 3) || (scalar(@bits) < 2);

        my ($type, $filename, $parent) = @bits;

        if ($layertype{$type}) {
            if (defined($parent)) {
                $s2kids{$parent}++;
            }
            fail("Can't find layer source file $filename") unless (-f $filename);
            fail("Core layer $filename shouldn't have a parent") if ($type eq 'core' && defined($parent));
            push @layers, \@bits;
        }
        elsif ($type eq 'include') {
            warning("Include is not yet implemented");
        }

        $line++;
    }

    my $base_checker;
    task "Compiling global builtins", sub {
        open(LAY, '<', 'res/s2layers/builtins.s2') or fail("Failed to open res/s2layers/builtins.s2");
        my $builtins_core = join('', <LAY>);
        close(LAY);

        $base_checker = new S2::Checker();

        my $cplr = new S2::Compiler({ 'checker' => $base_checker });

        my $compiled;
        eval {
            $cplr->compile_source({
                'type' => 'core',
                'source' => \$builtins_core,
                'output' => \$compiled,
                'untrusted' => 0,
                'builtinPackage' => "WebDrove::S2::Builtin",
            });
        };
        if ($@) { fail("Failed compiling res/s2layers/builtins.s2: $@"); }

        # All we need here is the checker. Throw away the compiler output.
        $compiled == undef;
    };

    foreach my $lay (@layers) {
        my ($type, $fn, $parent) = @$lay;

        fail("Parent layer $parent not loaded for $fn") if (defined($parent) && ! $s2ck{$parent});

        task "$type layer $fn" , sub {
            my $ck;
            if (defined($parent)) {
                $ck = $s2ck{$parent} or fail("Parent layer $parent is not loaded");
                $ck = $ck->clone(); # Need to take a copy so we can re-use the checker later
            }
            else {
                $ck = $base_checker->clone();
            }

            my $cplr = new S2::Compiler({ 'checker' => $ck });

            open(LAY, '<', $fn) or fail("Can't read layer source file $fn");
            my $source = join('',<LAY>);
            my $compiled;
            close(LAY);

            eval {
                $cplr->compile_source({
                    'type' => $type,
                    'format' => 'perloo',
                    'source' => \$source,
                    'output' => \$compiled,
                    'untrusted' => 0,
                    'builtinPackage' => "WebDrove::S2::Builtin",
                });
            };
            if ($@) { fail("Compile error: $@"); }


            WebDrove::S2::install_system_layer(\$compiled, $ck);
        };
    }

};

task "Populating page styles", sub {

};

exit(0);

sub task($&) {
    my ($desc, $code) = @_;

    begin_task($desc);
    $code->();
    end_task();
}

sub begin_task($) {
    my ($desc) = @_;
    step($desc) if $desc;
    $taskdepth++;
}

sub end_task() {
    $taskdepth--;
    print "\n" if $taskdepth == 0;
}

sub step($) {
    my ($desc) = @_;
    my $spaces = ("  " x $taskdepth);
    print ("  " x $taskdepth);
    $desc =~ s/\n/\n$spaces    /g;
    print "$spaces* $desc\n";
}

sub warning($) {
    my ($msg) = @_;

    print ("  " x $taskdepth);
    print "--- $msg ---\n";
}

sub fail($) {
    my ($msg) = @_;

    warning($msg);
    print "\nPopulation failed.\n";
    exit(1);
}
