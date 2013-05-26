package PDF::Imposition;

use 5.010001;
use strict;
use warnings;

use File::Basename qw/fileparse/;
use File::Spec;
use CAM::PDF;
use PDF::API2;
use File::Temp ();
use File::Copy;

=head1 NAME

PDF::Imposition - The great new PDF::Imposition!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use PDF::Imposition;

    my $foo = PDF::Imposition->new();
    ...

=head1 SUBROUTINES/METHODS

=head2 new(file => "file.pdf", suffix => "-imp", cover => 0, doublecover => 1)

Costructor. Options should be passed as list.

=cut

sub new {
    my ($class, %options) = @_;
    foreach my $k (keys %options) {
        # clean the options from internals
        delete $options{$k} if index($k, "_") == 0;
    }
    my $self = \%options;
    bless $self, $class;
}

=head2 Accessors

All the following accessors accept an argument, which sets the value.

=head3 doublecover

If the first two pages and the last two pages should be embedded in
the cover. As cover I refer to the pages which should *always* be the
first and the last, even if the total number of page is not a multiple
of four.

=head3 cover

Same as above, but reserve only one page, and keep page 2 and page
last-1 blank.

=cut

sub cover {
    my $self = shift;
    if (@_ == 1) {
        $self->{cover} = shift;
    }
    return $self->{cover};
}

sub doublecover {
    my $self = shift;
    if (@_ == 1) {
        $self->{doublecover} = shift;
    }
    return $self->{doublecover};
}

=head3 file

Unsurprisingly, the input file, which should exist.

=cut

sub file {
    my $self = shift;
    if (@_ == 1) {
        $self->{file} = shift;
    }
    my $f = $self->{file} || "";
    die "$f is not a file" unless -f $f;
    return $f;
}

sub _tmp_dir {
    my $self = shift;
    unless ($self->{_tmp_dir}) {
        $self->{_tmp_dir} = File::Temp->newdir(CLEANUP => 0);
    }
    return $self->{_tmp_dir};
}


=head3 outfile

The destination file of the imposition. You may prefer to use the
suffix method below, which takes care of the filename.

=head3 suffix

The suffix of the file. By default, '-imp', so test.pdf imposed will
be saved as 'test-imp.pdf'. If test-imp.pdf already exists, it will be
replaced merciless.

=cut

sub outfile {
    my $self = shift;
    if (@_ == 1) {
        $self->{outfile} = shift;
    }
    my $f = $self->{outfile};
    unless ($f) {
        my ($name, $path, $suffix) = fileparse($self->file,
                                               ".pdf", ".PDF");
        die $self->file . " has a suffix not recognized" unless $suffix;
        $f = File::Spec->catfile($path, $name . $self->suffix . $suffix);
        $self->{outfile} = $f;
    }
    return $f;
}

sub suffix {
    my $self = shift;
    if (@_ == 1) {
        $self->{suffix} = shift;
    }
    return $self->{suffix} || "-imp";
}


=head3 signature

The signature, must be a multiple of 4, or a range, like 20-100. If a
range is selected, the signature is determined to minize the white
pages left on the last signature.

=cut

sub signature {
    my $self = shift;
    if (@_ == 1) {
        $self->{signature} = shift;
    }
    my $sig = $self->{signature} || 0;
    return $self->_optimize_signature($sig) + 0; # force the scalar context
}

sub _optimize_signature {
    my ($self, $sig, $total_pages) = @_;
    unless ($total_pages) {
        $total_pages = $self->total_pages;
    }
    return 0 unless $sig;
    if ($sig =~ m/^[0-9]+$/s) {
        die "Signature must be a multiple of four" if $sig % 4;
        return $sig;
    }
    my ($min, $max);
    if ($sig =~ m/^([0-9]+)?-([0-9]+)?$/s) {
        $min = $1 || 4;
        $max = $2 || $total_pages;
        $min = $min + ((4 - ($min % 4)) % 4);
        $max = $max + ((4 - ($max % 4)) % 4);
        die "Bad range $max - $min" unless $max > $min;
        die "bad min $min" if $min % 4;
        die "bad max $max" if $max % 4;
    }
    else {
        die "Unrecognized range $sig";
    }
    my $signature = 0;
    my $roundedpages = $total_pages + ((4 - ($total_pages % 4)) % 4);
    my $needed = $roundedpages - $total_pages;
    die "Something is wrong" if $roundedpages % 4;
    if ($roundedpages <= $min) {
        wantarray ? return ($roundedpages, $needed) : return $roundedpages;
    }
    $signature = $self->_find_signature($roundedpages, $max);
    if ($roundedpages > $max) {
        while ($signature < $min) {
            $roundedpages += 4;
            $needed += 4;
            $signature = $self->_find_signature($roundedpages, $max)
        }
    }
    # warn "Needed $needed blank pages";
    wantarray ? return ($signature, $needed) : return $signature;
}

sub _find_signature {
    my ($self, $num, $max) = @_;
    die "not a multiple of four" if $num % 4;
    die "uh?" unless $num;
    my $i = $max;
    while ($i > 0) {
        # check if the the pagenumber is divisible by the signature
        # with modulo 0
        # warn "trying $i for $num / max $max\n";
        if (($num % $i) == 0) {
            return $i;
        }
        $i -= 4;
    }
    warn "Looped ended with no result\n";
}

=head2 Accessors

CAM::PDF is used to get the properties.

=head3 dimensions

Returns an hashref with the original pdf dimensions in points.

  { w => 800, h => 600 }

=head3 total_pages

Returns the number of pages

=head3 orig_width

=head3 orig_height

=cut

sub _populate_orig {
    my $self = shift;
    my $pdf = CAM::PDF->new($self->file);
    my ($x, $y, $w, $h) = $pdf->getPageDimensions(1); # use the first page
    warn $self->file . "use x-y offset, cannot proceed safely" if ($x + $y);
    die "Cannot retrieve paper dimensions" unless $w && $h;
    $self->{_dimensions} = { w => sprintf('%.2f', $w),
                             h => sprintf('%.2f', $h) };
    $self->{_total_orig_pages} = $pdf->numPages;
    undef $pdf;
}

sub dimensions {
    my $self = shift;
    unless ($self->{_dimensions}) {
        $self->_populate_orig;
    }
    # return a copy
    return { %{$self->{_dimensions}} };
}

sub total_pages {
    my $self = shift;
    unless ($self->{_total_orig_pages}) {
        $self->_populate_orig;
    }
    return $self->{_total_orig_pages};
}

sub orig_width {
    return shift->dimensions->{w};
}

sub orig_height {
    return shift->dimensions->{h};
}



=head3 page_sequence_for_booklet($pages, $signature)

Algorithm taken from psbook (Angus J. C. Duggan 1991-1995)

=cut

sub page_sequence_for_booklet {
    my ($self, $pages, $signature) = @_;
    unless (defined $pages) {
        $pages = $self->total_pages;
    }
    unless (defined $signature) {
        $signature = $self->signature;
    }
    my (@pgs, $maxpage);
    use integer;
    if (!$signature) {
        # rounding 
        $signature = $maxpage = $pages + ((4 - ($pages % 4)) % 4);
    }
    else {
        $maxpage = $pages + (($signature - ($pages % $signature)) % $signature)
    }
    for (my $currentpg = 0; $currentpg < $maxpage; $currentpg++) {
        my $actualpg = $currentpg - ($currentpg % $signature);
        my $modulo = $currentpg % 4;
        if ($modulo == 0 or $modulo == 3) {
            $actualpg += $signature - 1 - (($currentpg % $signature) / 2);
        }
        elsif ($modulo == 1 or $modulo == 2) {
            $actualpg += ($currentpg % $signature) / 2;
        }
        if ($actualpg < $pages) {
            $actualpg++;
        } else {
            $actualpg = undef;
        }
        push @pgs, $actualpg;
    }
    my @out;
    # then prepare the page pairs
    while (@pgs) {
        push @out, [ shift(@pgs), shift(@pgs) ];
    }
    return \@out;
}


=head3 in_pdf_obj

Internal usage. It's the PDF::API2 object used as source.

=head3 out_pdf_obj

Internal usage. The PDF::API2 object used as output.

=cut

sub in_pdf_obj {
    my $self = shift;
    unless ($self->{_input_pdf_obj}) {
        my ($basename, $path, $suff) = fileparse($self->file,
                                                 ".pdf", ".PDF");
        my $tmpfile = File::Spec->catfile($self->_tmp_dir,
                                          $basename . $suff);
        copy($self->file, $tmpfile) or die "copy to $tmpfile failed $!";
        my $input;
        eval {
            $input = PDF::API2->open($tmpfile);
        };
        if ($@) {
            # dirty trick to get a pdf 1.4
            my $src = CAM::PDF->new($tmpfile);
            $src->clean;
            my $tmpfile_copy =
              File::Spec->catfile($self->_tmp_dir,
                                  $basename . "-v14" . $suff);
            $src->output($tmpfile_copy);
            undef $src;
            $input = PDF::API2->open($tmpfile_copy);
        }
        die "Missing input" unless $input;
        $self->{_input_pdf_obj} = $input;
    }
    return $self->{_input_pdf_obj};
}

sub out_pdf_obj {
    my $self = shift;
    unless ($self->{_output_pdf_obj}) {
        $self->{_output_pdf_obj} = PDF::API2->new();
    }
    return $self->{_output_pdf_obj};
}

=head2 Main method

=head3 impose

Do the job and leave the output in C<$self->outfile>

=cut

sub impose {
    my $self = shift;
    # prototype
    $self->out_pdf_obj->mediabox(
                                 $self->orig_width * 2,
                                 $self->orig_height,
                                );
    my $seq = $self->page_sequence_for_booklet;
    foreach my $p (@$seq) {
        # loop over the pages
        my $left = $p->[0];
        my $right = $p->[1];
        my $page = $self->out_pdf_obj->page();
        my $gfx = $page->gfx();
        if (defined $left) {
            my $lpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $left);
            $gfx->formimage($lpage, 0, 0);
        }
        if (defined $right) {
            my $rpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $right);
            $gfx->formimage($rpage, $self->orig_width, 0);
        }
    }
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}


=head1 AUTHOR

Marco Pessotto, C<< <melmothx at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-pdf-imposition at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PDF-Imposition>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PDF::Imposition


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=PDF-Imposition>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/PDF-Imposition>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/PDF-Imposition>

=item * Search CPAN

L<http://search.cpan.org/dist/PDF-Imposition/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Marco Pessotto.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of PDF::Imposition
