#!perl
use strict;
use warnings;
use Test::More;
use PDF::Imposition;
use File::Spec::Functions;

if ($ENV{RELEASE_TESTING}) {
    plan tests => 16;
}
else {
    plan skip_all => "No release testing, skipping";
}

eval "require Test::LeakTrace";
if ($@) {
    plan skip_all => "Test::LeakTrace required for testing memory cycles";
    exit;
}

use Test::LeakTrace;

my @schemas = PDF::Imposition->available_schemas;

foreach my $schema (@schemas) {
    foreach my $testfile (qw/pdfv16.pdf sample2e.pdf/) {
        my $pdf = catfile(t => $testfile);
        my $outfile = catfile(t => output => join('-', 'leaks',
                                                  $schema, $testfile));
        if (-f $outfile) {
            unlink $outfile or die $!;
        };
        no_leaks_ok {
            my $imposer = PDF::Imposition->new(
                                               file => $pdf,
                                               schema => $schema,
                                               signature => '40-80',
                                               cover => 1,
                                               outfile => $outfile
                                              );
            $imposer->impose;
        } "No leaks found for $testfile $schema";
        ok (-f $outfile, "Generated $outfile");
    }
}

