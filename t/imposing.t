use strict;
use warnings;
use Test::More;
use File::Temp;
use File::Spec::Functions;
use File::Basename;
use File::Copy;
use PDF::Imposition;
use PDF::API2;
use Data::Dumper;
use Cwd;

# unfortunately, CAM::PDF is not capable of extracting the text from
# an imposed pdf, probably because of the nested pages, so they are
# considered something else than text.

# anyway, being that the tests are still useful in development
# environment, let's shell out.
my $pdftotext = system('pdftotext', '-v');
if ($pdftotext != 0) {
    plan skip_all => q{pdftotext not available, I can't proceed};
}
else {
    plan tests => 12;
}

my $testdir = File::Temp->newdir(CLEANUP => 0);
my $outputdir = catdir(getcwd(), "t", "output");
unless (-d $outputdir) {
    mkdir $outputdir or die "Cannot create $outputdir $!";
}

diag "Using $testdir as test directory";
unless (-d $testdir) {
    mkdir $testdir or die "cannot create $testdir => $!";
}
my $pdffile = File::Spec->catfile($testdir, "2up.pdf");

create_pdf($pdffile, 1..4);
diag "using $pdffile";

my $imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;

is_deeply(extract_pdf($imp->outfile),
          [
           [ 4, 1 ],
           [ 2, 3 ]
          ],
          "Simple imposition ok");

create_pdf($pdffile, 1..20);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 20, 1 ],
           [ 2, 19 ],
           [ 18, 3 ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 20 pages OK");

create_pdf($pdffile, 1..16);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->signature(4);
is($imp->signature, 4, "signature set at 4");
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [4,  1],
           [2 , 3],
           [8 , 5],
           [6,  7],
           [12, 9],
           [10, 11],
           [16, 13],
           [14, 15]
          ],
          "Signatures appear to work");

########################################################################
#                                                                      #
# We can't determine without a visual inspection if the page is placed #
# on the right side, (when one page is empty, but we suppose so :-)    #
#                                                                      #
########################################################################

create_pdf($pdffile, 1..19);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 1, undef ],
           [ 2, 19 ],
           [ 18, 3 ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 19 pages OK");

create_pdf($pdffile, 1..19);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->cover(1);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 19, 1 ],
           [ 2, undef ],
           [ 18, 3 ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 19 pages OK");


create_pdf($pdffile, 1..18);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 1, undef ],
           [ 2, undef ],
           [ 18, 3 ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 18 pages OK");

create_pdf($pdffile, 1..18);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->cover(1);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 18, 1 ],
           [ 2, undef ],
           [ 3, undef ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 18 pages OK");


create_pdf($pdffile, 1..17);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 1, undef ],
           [ 2, undef ],
           [ 3, undef ],
           [ 4, 17 ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 17 pages OK");

create_pdf($pdffile, 1..17);
$imp = PDF::Imposition->new(file => $pdffile);
$imp->cover(1);
$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 17, 1 ],
           [ 2, undef ],
           [ 3, undef ],
           [ 4, undef ],
           [ 16, 5 ],
           [ 6, 15 ],
           [ 14, 7 ],
           [ 8, 13 ],
           [ 12, 9 ],
           [ 10, 11]
          ],
          "Imposing 18 pages OK");

move($imp->outfile, $outputdir)
  or die "Cannot move " . $imp->outfile . " in " . $outputdir;
diag "PDF 2up left in " . catfile($outputdir, basename($pdffile));


$pdffile = File::Spec->catfile($testdir, "2down.pdf");
create_pdf($pdffile, 1..17);
$imp = PDF::Imposition->new(
                            file => $pdffile,
                            schema => '2down',
                           );

$imp->impose;

# here the odd pages are on the left and the even on the right. This
# is basically an artefact of the text extraction, and of the rotation
# of the page, I guess. There is no way we can check this blindly.

is_deeply(extract_pdf($imp->outfile),
          [
           [ 1, undef ],
           [ 2, undef ],
           [ 3, undef ],
           [ 17, 4 ],
           [ 5, 16 ],
           [ 15, 6 ],
           [ 7, 14 ],
           [ 13, 8 ],
           [ 9, 12 ],
           [ 11, 10]
          ],
          "Imposing 17 pages OK");

create_pdf($pdffile, 1..17);
$imp = PDF::Imposition->new(
                            file => $pdffile,
                            schema => '2down',
                            cover => 1,
                           );

$imp->impose;
is_deeply(extract_pdf($imp->outfile),
          [
           [ 1 ,17 ],
           [ 2, undef ],
           [ 3, undef ],
           [ 4, undef ],
           [ 5, 16 ],
           [ 15, 6 ],
           [ 7, 14 ],
           [ 13, 8 ],
           [ 9, 12 ],
           [ 11, 10]
          ],
          "Imposing 17 pages OK");


move($imp->outfile, $outputdir)
  or die "Cannot move " . $imp->outfile . " in " . $outputdir;
diag "PDF 2down left in " . catfile($outputdir, basename($pdffile));


# print Dumper($imp->page_sequence_for_booklet);
          

sub create_pdf {
    my ($filename, @pages) = @_;
    my $pdf = PDF::API2->new();
    # common settings
    $pdf->mediabox(500,500);
    my $font = $pdf->corefont('Helvetica-Bold');
    for my $p (@pages) {
        my $page = $pdf->page();
        my $text = $page->text();
        $text->font($font, 20);
        $text->translate(200, 200);
        $text->text("Page $p");
    }
    $pdf->saveas($filename);
    return;
}

sub extract_pdf {
    my $pdf = shift;
    my $txt = $pdf;
    $txt =~ s/\.pdf$/.txt/;
    system(pdftotext => $pdf) == 0 or die 'pdftotext failed $?';
    local $/ = undef;
    open (my $fh, '<', $txt) or die "cannot open $txt $!";
    my $ex = <$fh>;
    close $fh;
    return extract_pages($ex);
}

sub extract_pages {
    my $rawtext = shift;
    # split at ^L
    my @pages = split /\x{0C}/, $rawtext;
    my @out;
    # print Dumper(\@pages);
    foreach my $p (@pages) {
        my @nums;
        # this is (of course) very fragile;
        if ($p =~ m/\s*(Page (\d+))?\s*?\n\n\s*(Page (\d+))?\s*/s) {
            push @out, [$2, $4];
        }
        else {
            die "Unparsable chunk: $p\n";
        }
    }
    return \@out;
}
