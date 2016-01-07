package PDF::Imposition;

use strict;
use warnings;
use Module::Load;
use Types::Standard qw/Enum Object Maybe Str/;
use File::Temp;
use File::Copy;
use File::Spec;
use File::Basename;
use Data::Dumper;
use namespace::clean;

use constant {
    DEBUG => $ENV{AMW_DEBUG},
};

use Moo;

=head1 NAME

PDF::Imposition - Perl module to manage the PDF imposition

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

This module is meant to simplify the so-called imposition, i.e.,
rearrange the pages of a PDF to get it ready to be printed and folded,
with more logical pages placed on the sheet, usually (but not
exclusively) on recto and verso.

This is what the routine looks like:

    use PDF::Imposition;
    my $imposer = PDF::Imposition->new(file => "test.pdf",
                                       outfile => "out.pdf",
                                       # or # suffix => "-imposed",
                                       signature => "40-80",
                                       cover => 0,
                                       schema => "2up");
    $imposer->impose;
    print "Output left in " . $imposer->outfile;


Please note that you don't pass the PDF dimensions (which are
extracted from the source PDF itself by the class, using the very
first page: if you want imposition, I do the reasonable assumption you
have all the pages with the same dimensions).

=head1 METHODS

=head2 Costructor options and accessors

=head3 file

The input file

=head3 outfile

The output file

=head3 suffix

The suffix of the output file (don't mix the two options).

=head3 schema

The schema to use.

=over 4 

=item 2up

See L<PDF::Imposition::Schema2up>

=item 2down

See L<PDF::Imposition::Schema2down>

=item 2x4x2

See L<PDF::Imposition::Schema2x4x2>

=item 2side

See L<PDF::Imposition::Schema2side>

=item 4up

See L<PDF::Imposition::Schema4up>

=item 1x4x2cutfoldbind

See L<PDF::Imposition::Schema1x4x2cutfoldbind>

=item 1repeat2top

See L<PDF::Imposition::Schema1repeat2top>

=item 1repeat2side

See L<PDF::Imposition::Schema1repeat2side>

=item 1repeat4

See L<PDF::Imposition::Schema1repeat4>

=item ea4x4

See L<PDF::Imposition::Schemaea4x4>

=item 1x8x2

See L<PDF::Imposition::Schema1x8x2>

=item 1x1

See L<PDF::Imposition::Schema1x1>

=back

=head3 cover

If the last logical page must be placed at the very end, B<after> the
blank pages used to pad the signature. (C<2up>, C<2down>
C<1x4x2cutfoldbind>, C<4up>, C<1x1> only).

Often it happens that we want the last page of the pdf to be the last
one on the physical booklet after folding. If C<cover> is set to a
true value, the last page of the logical pdf will be placed on the
last page of the last signature.

=head3 signature

The signature (integer multiple of four or range): C<2up> and C<2down> only.

=head3 paper

Passing this option triggers the cropmarks. While the original
dimensions are left unchanged, this size represents the size of the
logical page which is actually imposed.

For example, you have a PDF in a6, you pass C<a5> as paper, and schema
C<2up>, you are going to get an a4 with 2 a6 with cropmarks.

This option is passed to L<PDF::Cropmarks>. See the module
documentation for the accepted values.


=head3 paper_thickness

This option is passed to L<PDF::Cropmarks>. See the module
documentation for the accepted values.

=head2 impose

Main method which does the actual job. You have to call this to get
your file. It returns the output filename.

=cut



sub BUILDARGS {
    my ($class, %options) = @_;
    my $schema = lc(delete $options{schema} || '2up'); #  default
    my $loadclass = __PACKAGE__ . '::Schema' . $schema;
    my %our_options = map { $_ => delete $options{$_} } qw/paper
                                                           paper_thickness/;
    load $loadclass;
    my $imposer = $loadclass->new(%options);
    $our_options{imposer} = $imposer;
    $our_options{schema} = $schema;
    return \%our_options;
}

has schema => (is => 'ro',
               default => '2up',
               isa => Enum[__PACKAGE__->available_schemas]);

has imposer => (is => 'ro',
                required => 1,
                handles => [qw/file outfile suffix
                               cover
                               signature
                               computed_signature
                               total_pages
                               orig_width
                               orig_height
                               dimensions
                               total_output_pages
                              /],
                isa => Object);

has paper => (is => 'ro',
              isa => Maybe[Str]);

has paper_thickness => (is => 'ro',
                        isa => Maybe[Str]);

sub impose {
    my $self = shift;

    # no cropmarks required
    unless ($self->paper) {
        return $self->imposer->impose;
    }

    my $input = $self->file;
    my $basename = basename($input);
    my $tmpdir = File::Temp->newdir(CLEANUP => !DEBUG);
    my $crop_output = File::Spec->catfile($tmpdir, $basename);
    print "# cropping output in $crop_output\n" if DEBUG;

    # doesn't exist yet. This will die if we try to open the file
    # before the preprocessing is done.

    # classes that supports the cover options need to normalized the pdf first,
    # and pass the exact number of the signature.

    if ($self->schema ne '1x1' and $self->imposer->can('cover')) {
        require PDF::Imposition::Schema1x1;
        my $normalized = File::Spec->catfile($tmpdir, '1x1.pdf');
        my %args = (
                    file => $input,
                    signature => $self->signature,
                    cover => $self->cover,
                    outfile => $normalized,
                    pages_per_sheet => $self->imposer->pages_per_sheet,
                   );
        my $pre = PDF::Imposition::Schema1x1->new(%args);
        $pre->impose;
        print "preprocessor: " . Dumper($pre) if DEBUG;
        unless ($normalized eq $crop_output) {
            copy($normalized, $crop_output)
              or die "Cannot copy $normalized to $crop_output $!";
        }
        print "# Computed signature is " . $pre->computed_signature . "\n"
          if DEBUG;
        $self->_add_cropmarks($crop_output,
                              signature => $pre->computed_signature);
        # flip the input to normalized, but keep the basename
        # now we have the input on normalized.
    }
    else {
        copy($input, $crop_output);
        $self->_add_cropmarks($crop_output);
    }
    die "pdf opened too early" if $self->imposer->_in_pdf_object_is_open;
    # flip the input
    print "Setting file to $crop_output\n" if DEBUG;
    $self->file($crop_output);
    my $outpdf = $self->imposer->impose;
    # flip back to the original in any case.
    print "Setting file to $input\n" if DEBUG;
    $self->file($input);
    return $outpdf;
}

sub _add_cropmarks {
    # add cropmarks in place.
    my ($self, $pdf, %options) = @_;
    my $cropmark_paper = $self->paper;
    return unless $cropmark_paper;
    print "# Cropping $pdf in place\n" if DEBUG;
    require PDF::Cropmarks;
    my $tmpdir = File::Temp->newdir(CLEANUP => !DEBUG);
    print "Using $tmpdir for cropping\n" if DEBUG;
    my $original = File::Spec->catfile($tmpdir, "in.pdf");
    my $processed = File::Spec->catfile($tmpdir, "out.pdf");
    copy ($pdf, $original) or die "Cannot copy $pdf to $original $!";
    my %args = (
                input => $original,
                output => $processed,
                paper => $cropmark_paper,
                %options,
                # these have precedence!
                $self->imposer->cropmarks_options,
               );
    if (my $thickness = $self->paper_thickness) {
        $args{paper_thickness} = $thickness;
    }
    # process
    my $cropper = PDF::Cropmarks->new(%args);
    $cropper->add_cropmarks;
    print "Cropper: " . Dumper($cropper) if DEBUG;
    # copy back
    copy($processed, $pdf);
}


=head2 available_schemas

Called on the class (not on the object returned by C<new>) will report
the list of available schema.

E.g.

 PDF::Imposition->available_schemas;

=cut

sub available_schemas {
    return qw/2up 2down 2side 2x4x2 1x4x2cutfoldbind
              4up 1repeat2top 1repeat2side 1repeat4 ea4x4
              1x8x2 1x1/
}

=head1 INTERNALS

=over 4

=item BUILDARGS

=item imposer

=back

=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to the author's email. If
you find a bug, please provide a minimal example file which reproduces
the problem (so I can add it to the test suite).

Or, at your discretion, feel free to use the CPAN's RT.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PDF::Imposition

=head1 REPOSITORY

L<https://github.com/melmothx/pdf-imposition-perl>

=head1 SEE ALSO

=over 4

=item psutils

L<http://knackered.org/angus/psutils/> (shipped by any decent
GNU/Linux distro and in TeXlive!). If you don't bother the
PDF->PS->PDF route, it's a great and useful tool which just aged well.

=item pdfpages

L<http://www.ctan.org/pkg/pdfpages>

=item pdfjam

L<http://www2.warwick.ac.uk/fac/sci/statistics/staff/academic-research/firth/software/pdfjam/>
(buil on the top of pdfpages)

=item ConTeXt

L<http://wiki.contextgarden.net/Imposition>

The names of schemas are taken straight from the ConTeXt ones (if
existing), as described in the book I<Layouts in context>, by Willi
Egger, Hans Hagen and Taco Hoekwater, 2011.

=back

=head1 TODO

The idea is to provide a wide range of imposition schemas (at least
the same provided by ConTeXt). This could require some time. If you
want to contribute, feel free to fork the repository and send a pull
request or a patch (please include documentation and at some tests).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of either: the GNU General Public License as
published by the Free Software Foundation; or the Artistic License.

=cut

1; # End of PDF::Imposition
