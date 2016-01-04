#!perl

use strict;
use warnings;
use Test::More;
use PDF::Imposition;
use PDF::API2;
use File::Spec::Functions;

my @schemas = PDF::Imposition->available_schemas;

plan tests => @schemas * 4;

my $testdir = File::Temp->newdir(CLEANUP => 1);
my $outputdir = catdir("t", "output", $PDF::Imposition::VERSION . '-cropmarks');
unless (-d $outputdir) {
    mkdir catdir("t", "output") unless -d catdir("t", "output");
    mkdir $outputdir or die "Cannot create $outputdir $!";
}

my $pdf = catfile($testdir, 'input.pdf');
{
    my $pdfobj = PDF::API2->new();
        # common settings
    $pdfobj->mediabox(80, 120);
    my $font = $pdfobj->corefont('Helvetica-Bold');
    for my $p (1..15) {
        my $page = $pdfobj->page();
        my $text = $page->text();
        $text->font($font, 20);
        $text->translate(40, 60);
        $text->text_center("Pg $p");
        my $line = $page->gfx;
        $line->linewidth(1);
        $line->strokecolor('black');
        $line->rectxy(1, 1, 79, 119);
        $line->stroke;
    }
    $pdfobj->saveas($pdf);
}

my %enabled = (
               '1x1' => 0,
               '2up' => 1,
              );

foreach my $schema (@schemas) {
    foreach my $cover (0..1) {
      SKIP: {
            skip "$schema test disabled", 2 unless $enabled{$schema};
            my $out = catfile($outputdir, $schema . ($cover ? '-cover' : '')
                              . '-cropmarks.pdf');
            unlink $out if $out;
            diag "Testing cropmarks against $schema, cover: $cover";
            ok (! -f $out, "Directory clean, no $out");
            my $imposer = PDF::Imposition->new(schema => $schema,
                                               file => $pdf,
                                               outfile => $out,
                                               cover => $cover,
                                               cropmarks_paper_thickness => '5mm',
                                               cropmarks => "150pt:200pt");
            $imposer->impose;
            ok (-f $out, "$out produced");
        }
    }
}
