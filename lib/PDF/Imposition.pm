package PDF::Imposition;

use 5.010001;
use strict;
use warnings;

use Module::Load;

=head1 NAME

PDF::Imposition - Perl module to manage the PDF imposition

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';


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
first page: if you want imposition, I do the resonable assumption you
have all the pages with the same dimensions).

=head1 METHODS

=head2 Constructor

=head3 new ( file => $file, schema => $schema, ...)

This is the only method provided by this class. The constructor
doesn't return itself, but instead load, build and return a
L<PDF::Imposition::Schema> subclass object, defaulting to
L<PDF::Imposition::Schema2up> (which is assumed to be the most common
scenario).

If you prefer, you can load the right class yourself.

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

=back

=item cover

If the last logical page must be placed at the very end, B<after> the
blank pages used to pad the signature. (C<2up> and C<2down> only).

=item signature

The signature (integer multiple of four or range): C<2up> and C<2down> only.

=back

=cut


sub new {
    my ($class, %options) = @_;
    foreach my $k (keys %options) {
        # clean the options from internals
        delete $options{$k} if index($k, "_") == 0;
    }
    my $schema = delete $options{schema} || '2up'; #  default
    my $loadclass = __PACKAGE__ . '::Schema' . $schema;
    load $loadclass;
    return $loadclass->new(%options);
}



=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to the author's email. If
you find a bug, please provide a minimal example file which reproduces
the problem (so I can add it to the test suite).

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PDF::Imposition

=head1 REPOSITORY

L<https://gitorious.org/perl-pdf-imposition>

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
(buil on the top of psutils)

=item ConTeXt

L<http://wiki.contextgarden.net/Imposition>

The names of schemas are taken straight from the ConTeXt one, as
described in the Book I<Layouts in context>, by Willi Egger, Hans
Hagen and Taco Hoekwater, 2011.

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
