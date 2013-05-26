#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec::Functions;
use PDF::Imposition;
use Data::Dumper;
use Try::Tiny;

plan tests => 15;

my $pdfi = PDF::Imposition->new;

$pdfi->file(catfile(t => "sample2e.pdf"));
$pdfi->cover(1);
$pdfi->suffix("-test");

testaccessors($pdfi);

$pdfi = PDF::Imposition->new(
                             file => catfile(t => "sample2e.pdf"),
                             cover => 1,
                             suffix => "-test",
                            );

testaccessors($pdfi);

$pdfi = PDF::Imposition->new(
                             file => catfile(t => "sample2e.pdf"),
                             cover => 1,
                             suffix => "-test",
                             outfile => "prova_pdf.pdf"
                            );

is($pdfi->outfile, "prova_pdf.pdf");

$pdfi = PDF::Imposition->new;

my $err = 0;
try {
    $pdfi->file("xxx");
} catch {
    $err++;
    print $_;
};
ok($err, "non existent file raises exception");

$err = 0;
try {
    $pdfi->file("");
} catch {
    $err++;
    print $_;
};
ok($err, "empty string raises exception");


$err = 0;
try {
    $pdfi->file("t");
} catch {
    $err++;
    print $_;
};
ok($err, "directory raises exception");


$err = 0;
$pdfi->file("README");
try {
    $pdfi->outfile;
} catch {
    print $_;
    $err++;
};
ok($err, "not a pdf raises exception when calling ->outfile");


sub testaccessors {
    my $pdf = shift;
    # print Dumper($pdf);
    ok($pdf->outfile, "outfile ok" . $pdf->outfile);
    is($pdf->outfile, catfile(t => "sample2e-test.pdf"), "sample2-test.pdf");
    is($pdf->cover, 1, "cover is true");
    is($pdf->suffix, "-test", "suffix exists");
    $pdf->outfile("test.pdf");
    is($pdf->outfile, "test.pdf", "outfile overwrites");
}

