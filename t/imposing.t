use strict;
use warnings;
use Test::More;
use File::Spec::Functions;
use PDF::Imposition;
use PDF::API2;
use Data::Dumper;

# unfortunately, CAM::PDF is not capable of extracting the text from
# an imposed pdf, probably because of the nested pages, so they are
# considered something else than text.

# anyway, being that the tests are still useful in development
# environment, let's shell out.
$| = 1;
print "Using ";
my $pdftotext = system('pdftotext', '-v');
if ($pdftotext != 0) {
    plan skip_all => q{pdftotext not available, I can't proceed};
}
else {
    plan tests => 4;
}

my $testdir = File::Temp->newdir(CLEANUP => 0);
diag "Using $testdir as test directory";
unless (-d $testdir) {
    mkdir $testdir or die "cannot create $testdir => $!";
}
my $pdffile = File::Spec->catfile($testdir, "scratch.pdf");

create_pdf($pdffile, 1..4);
diag "using $pdffile";

my $imp = PDF::Imposition->new(file => $pdffile);
$imp->impose;
print $imp->outfile, "\n";
print Dumper();

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
    foreach my $p (@pages) {
        my @nums;
        while ($p =~ m/Page (\d+)/g) {
            push @nums, $1;
        }
        push @out, \@nums;
    }
    return \@out;
}
