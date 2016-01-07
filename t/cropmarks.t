#!perl

use strict;
use warnings;
use Test::More;
use PDF::Imposition;
use PDF::API2;
use File::Spec::Functions;
use File::Temp;
use File::Path qw/remove_tree make_path/;

my @schemas = PDF::Imposition->available_schemas;

plan tests => @schemas * 4;

my $outputdir = catdir("t", "output", $PDF::Imposition::VERSION . '-cropmarks');
if (-d $outputdir) {
    remove_tree($outputdir);
}
make_path($outputdir);

my $pdf = catfile($outputdir, 'sample.pdf');
{
    my $pdfobj = PDF::API2->new();
        # common settings
    $pdfobj->mediabox(80, 120);
    my $font = $pdfobj->corefont('Helvetica-Bold');
    for my $p (1..29) {
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
               '1x1'              => 0,
               '2up'              => 0,
               '2down'            => 0,
               '2side'            => 0,
               '2x4x2'            => 0,
               '1x4x2cutfoldbind' => 1,
              );

foreach my $schema (@schemas) {
    foreach my $cover (0..1) {
      SKIP: {
            skip "$schema " . ($cover ? "with cover" : "")
              . " test disabled", 2 unless $enabled{$schema};
            my $out = catfile($outputdir, $schema . ($cover ? '-cover' : '')
                              . '-cropmarks.pdf');
            unlink $out if $out;
            diag "Testing cropmarks against $schema, cover: $cover";
            ok (! -f $out, "Directory clean, no $out");
            my $imposer = PDF::Imposition->new(schema => $schema,
                                               file => $pdf,
                                               outfile => $out,
                                               cover => $cover,
                                               paper => "200pt:300pt",
                                               paper_thickness => '1mm',
                                              );
            $imposer->impose;
            ok (-f $out, "$out produced");
        }
    }
}

unlink $pdf;
