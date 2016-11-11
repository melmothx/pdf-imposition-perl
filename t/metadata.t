#!perl
use utf8;
use strict;
use warnings;
use PDF::API2;
use File::Temp;
use File::Spec;
use Test::More tests => 1;
use Data::Dumper;
use PDF::Imposition;

my $wd = File::Temp->newdir(CLEANUP => !$ENV{NO_CLEANUP});
diag "Working in $wd";

my $target = File::Spec->catfile($wd, 'metadata.pdf');
my $outfile = File::Spec->catfile($wd, 'metadata-out.pdf');
my %meta = (
            Author => 'Author á Pinco ĐŠć',
            Title => 'Title á Pinco ĐŠć',
            Subject => 'Subject á Pinco ĐŠć',
            Keywords => 'Keywords á Pinco ĐŠć',
           );
{
    my $pdf = PDF::API2->new();
    $pdf->mediabox(80, 120);
    my $font = $pdf->corefont('Helvetica-Bold');
    my $page = $pdf->page;
    my $text = $page->text;
    $text->font($font, 20);
    $text->text_center('Baf');
    $pdf->info(%meta);
    $pdf->saveas($target);
}
{
    my $pdf = PDF::API2->open($target);
    my %got = $pdf->info;
    delete $got{Producer};
    is_deeply(\%got, \%meta, "metadata ok");
    $pdf->end;
}

{
    PDF::Imposition->new(file => $target,
                         outfile => $outfile,
                         schema => "2up")->impose;
    my $pdf = PDF::API2->open($outfile);
    my %got = $pdf->info;
    delete $got{Producer};
    is_deeply(\%got, \%meta, "metadata ok after imposing");
    $pdf->end;
}

{
    PDF::Imposition->new(file => $target,
                         outfile => $outfile,
                         paper => "400pt:500pt",
                         paper_thickness => '1mm',
                         schema => "2up")->impose;
    my $pdf = PDF::API2->open($outfile);
    my %got = $pdf->info;
    delete $got{Producer};
    is_deeply(\%got, \%meta, "metadata ok after imposing with cropmarks");
    $pdf->end;
}

# and modify it in place

{
    my $pdf = PDF::API2->open($target);
    $pdf->info(%meta);
    $pdf->saveas($target);
    $pdf = PDF::API2->open($target);
    my %got = $pdf->info;
    delete $got{Producer};
    is_deeply(\%got, \%meta, "metadata ok after modifying it in place");
    $pdf->end;
}

