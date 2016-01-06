package PDF::Imposition;

use strict;
use warnings;
use Module::Load;
use Types::Standard qw/Enum Object/;
use namespace::clean;

use Moo;

=head1 NAME

PDF::Imposition - Perl module to manage the PDF imposition

=head1 VERSION

Version 0.16

=cut

our $VERSION = '0.16';


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

=head2 new ( file => $file, schema => $schema, ...)

Constructor.

=head3 Options

=over 4

=item file

The input file

=item outfile

The output file

=item suffix

The suffix of the output file (don't mix the two options).

=item schema

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

=item cover

If the last logical page must be placed at the very end, B<after> the
blank pages used to pad the signature. (C<2up> and C<2down> only).

=item signature

The signature (integer multiple of four or range): C<2up> and C<2down> only.

=back

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

sub impose {
    my $self = shift;
    return $self->imposer->impose;
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
