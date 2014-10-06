#!perl

use strict;
use warnings;

use Test::More;
use PDF::Imposition;
use File::Spec::Functions;

eval "use Test::Memory::Cycle";

if ($ENV{RELEASE_TESTING} && !$@) {
    plan tests => 20;
}
else {
    plan skip_all => "No release testing, skipping";
}

my @schemas = PDF::Imposition->available_schemas;
foreach my $schema (@schemas) {
    foreach my $testfile (qw/pdfv16.pdf sample2e.pdf/) {
        my $pdf = catfile(t => $testfile);
        my $outfile = catfile(t => output => join('-', 'cycle',
                                                  $schema, $testfile));

        if (-f $outfile) {
            unlink $outfile or die $!;
        }

        my $imposer = PDF::Imposition->new(
                                           file => $pdf,
                                           schema => $schema,
                                           signature => '40-80',
                                           cover => 1,
                                           outfile => $outfile
                                          );
        $imposer->impose;
        memory_cycle_ok($imposer, "No memory cycles found for $schema $testfile");
        ok(-f $outfile, "Produced $outfile");
    }
}

