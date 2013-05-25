#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec::Functions;
use PDF::Imposition;
use Data::Dumper;
use Try::Tiny;
use CAM::PDF;
use PDF::API2;

my $sample = catfile(t => "sample2e.pdf");
my $imposer = PDF::Imposition->new(file => $sample);

is($imposer->total_pages, 3, "pages ok");
is($imposer->orig_width, 595.28, "width ok");
is($imposer->orig_height, 841.89, "height ok");
is_deeply($imposer->dimensions, {
                                 w => 595.28,
                                 h => 841.89,
                                }, "dimension ok");

done_testing;

my $orig = "16.pdf";
my $src = CAM::PDF->new(catfile(t => $orig));
my $out = catfile(t => "test.pdf");
my $result = catfile(t => 'newpdf.pdf');

foreach ($out, $result) {
    if (-f $_) {
        unlink $_ or die "$!";
    }
}

$src->clean;
$src->output($out);
my $clean = PDF::API2->open($out);
# print $clean->pages();

my $pdf = PDF::API2->new();
$pdf->mediabox('A4');
my $old = PDF::API2->open($out);
my $page = $pdf->page();
my $gfx = $page->gfx();

# Import Page 2 from the old PDF
my $xo = $pdf->importPageIntoForm($old, 2);

# Add it to the new PDF's first page at 1/2 scale
$gfx->formimage($xo, 0, 0, 0.5);
$gfx->formimage($xo, 100, 100, 0.5);

$page = $pdf->page();
$gfx = $page->gfx();

# Import Page 2 from the old PDF
$xo = $pdf->importPageIntoForm($old, 2);
# Add it to the new PDF's first page at 1/2 scale
$gfx->formimage($xo);
$xo = $pdf->importPageIntoForm($old, 3);
$gfx->translate(100,100);
$gfx->rotate(10);

$gfx->formimage($xo);

$pdf->saveas($result);
