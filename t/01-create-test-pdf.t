#!/usr/bin/env perl

use strict;
use warnings;
use File::Spec;
use Test::More;
use File::Temp ();
use PDF::API2;
use CAM::PDF;
use CAM::PDF::PageText;

plan tests => 1;
my $testdir = File::Temp->newdir(CLEANUP => 1);
diag "Using $testdir as test directory";
unless (-d $testdir) {
    mkdir $testdir or die "cannot create $testdir => $!";
}
my $pdffile = File::Spec->catfile($testdir, "scratch.pdf");

# create the array:
my @pages;
for (1..20) {
    push @pages, "Page $_";
}

my $pdf = PDF::API2->new();
my $font = $pdf->corefont('Helvetica-Bold');
$pdf->mediabox(500, 400);

for my $p (@pages) {
    my $page = $pdf->page();
    my $text = $page->text();
    $text->font($font, 20);
    $text->translate(200, 200);
    $text->text($p);
}
$pdf->saveas($pdffile);
undef $pdf;                     # destroy

my $pdfextract = CAM::PDF->new($pdffile);

my @extracted;
for my $p (0 .. $#pages) {
    my $page = $pdfextract->getPageContentTree($p + 1);
    my $ex = CAM::PDF::PageText->render($page);
    chomp $ex;
    push @extracted, $ex;
}

diag "If you fail this test, your installation of PDF::API2";
diag "and/or CAM::PDF is broken";

is_deeply(\@extracted, \@pages, "Text extraction works");
