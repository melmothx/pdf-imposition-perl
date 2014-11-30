package PDF::Imposition::Schema2up;
use strict;
use warnings;
use base "PDF::Imposition::Schema";

=head1 NAME

PDF::Imposition::Schema2up - Imposition schema 2up (booklet)

=head1 SYNOPSIS

    use PDF::Imposition::Schema2up;
    my $imposer = PDF::Imposition::Schema2up->new(
                                                  signature => "10-20",
                                                  file => "test.pdf",
                                                  output => "out.pdf",
                                                  cover => 1,
                                                 );
    # or call the methods below to set the values, and then call:
    $imposer->impose;

The output pdf will be in C<$imposer->output>

=head1 SCHEMA EXPLANATION

This schema is a variable and dynamic method. The signature, i.e., the
booklets which compose the document, are not fixed-sized, but can be
altered. The purpose is to have 1 or more booklets that you print
recto-verso and just fold to have your home-made book (this schema is
aimed to DIY people).

Say you have a text with 60 pages in A5: you would print it on A4,
double-side, take the pile out of the printer, fold it and clip it.

The schema looks like (for a signature of 8 pages on 2 sheets):

       RECTO S.1     VERSO S.1
     +-----+-----+  +-----+-----+ 
     |     |     |  |     |     | 
     |  8  |  1  |  |  2  |  7  | 
     |     |     |  |     |     | 
     +-----+-----+  +-----+-----+ 

       RECTO S.2     VERSO S.2
     +-----+-----+  +-----+-----+
     |     |     |  |     |     |
     |  6  |  3  |  |  4  |  5  |
     |     |     |  |     |     |
     +-----+-----+  +-----+-----+

=head1 METHODS

=head2 Public methods

=head3 signature

The signature, must be a multiple of 4, or a range, like the string
"20-100". If a range is selected, the signature is determined
heuristically to minimize the white pages left on the last signature.
The wider the range, the best the results.

This is useful if you are doing batch processing, and you don't know
the number of page in advance (so you can't tweak the source pdf to
have a suitable number of page via text-block dimensions or font
changes).

Typical case: you define a signature of 60 pages, and your PDF happens
to have 61 pages. How unfortunate, and you just can't put out a PDF
with 59 blank pages. The manual solution is to change something in the
document to get it under 60 pages, but this is not always viable or
desirable. So you define a dynamic range for signature, like 20-60,
(so the signature will vary between 20 and 60) and the routine will
find the best one, which in this particular case happens to be 32 (so
the text will have two booklets, and the second will have 3 blank
pages).

Es.

  $imposer->signature("20-60");

Keep in mind that a signature with more than 100 pages is not suitable
to be printed and folded at home (too thick), so to get some
acceptable result, the sheets must be cut and glued together by a
binder, so in this case you want to go with the single signature for
the whole pdf.

If no signature is specified, the whole text will be imposed on a
single signature, regardeless of its size.


=cut

sub signature {
    my $self = shift;
    if (@_ == 1) {
        $self->{signature} = shift;
    }
    my $sig = $self->{signature} || 0;
    return $self->_optimize_signature($sig) + 0; # force the scalar context
}

=head3 pages_per_sheet

The number of logical pages which fit on a sheet, recto-verso. For
this class, it will always return 4. Subclasses are allowed to change
this.

=cut

sub pages_per_sheet {
    return shift->{page_per_sheet} || 4;
}

sub _set_pages_per_sheet {
    # private
    my ($self, $num) = @_;
    die "bad usage" unless $num;
    if ($num == 2 or $num == 4 or $num == 8 or $num == 16 or $num == 32) {
        $self->{page_per_sheet} = $num;
    }
    else {
        die "bad number";
    }
    return $self->pages_per_sheet;
}

sub _optimize_signature {
    my ($self, $sig, $total_pages) = @_;
    unless ($total_pages) {
        $total_pages = $self->total_pages;
    }
    return 0 unless $sig;
    my $ppsheet = $self->pages_per_sheet or die;
    if ($sig =~ m/^[0-9]+$/s) {
        die "Signature must be a multiple of $ppsheet" if $sig % $ppsheet;
        return $sig;
    }
    my ($min, $max);
    if ($sig =~ m/^([0-9]+)?-([0-9]+)?$/s) {
        $min = $1 || $ppsheet;
        $max = $2 || $total_pages;
        $min = $min + (($ppsheet - ($min % $ppsheet)) % $ppsheet);
        $max = $max + (($ppsheet - ($max % $ppsheet)) % $ppsheet);
        die "Bad range $max - $min" unless $max > $min;
        die "bad min $min" if $min % $ppsheet;
        die "bad max $max" if $max % $ppsheet;
    }
    else {
        die "Unrecognized range $sig";
    }
    my $signature = 0;
    my $roundedpages = $total_pages + (($ppsheet - ($total_pages % $ppsheet)) % $ppsheet);
    my $needed = $roundedpages - $total_pages;
    die "Something is wrong" if $roundedpages % $ppsheet;
    if ($roundedpages <= $min) {
        wantarray ? return ($roundedpages, $needed) : return $roundedpages;
    }
    $signature = $self->_find_signature($roundedpages, $max);
    if ($roundedpages > $max) {
        while ($signature < $min) {
            $roundedpages += $ppsheet;
            $needed += $ppsheet;
            $signature = $self->_find_signature($roundedpages, $max)
        }
    }
    # warn "Needed $needed blank pages";
    wantarray ? return ($signature, $needed) : return $signature;
}

sub _find_signature {
    my ($self, $num, $max) = @_;
    my $ppsheet = $self->pages_per_sheet or die;
    die "not a multiple of $ppsheet" if $num % $ppsheet;
    die "uh?" unless $num;
    my $i = $max;
    while ($i > 0) {
        # check if the the pagenumber is divisible by the signature
        # with modulo 0
        # warn "trying $i for $num / max $max\n";
        if (($num % $i) == 0) {
            return $i;
        }
        $i -= $ppsheet;
    }
    warn "Looped ended with no result\n";
}


=head2 Internal (but documented) methods

=head3 page_sequence_for_booklet($pages, $signature)

Algorithm taken/stolen from C<psbook> (Angus J. C. Duggan 1991-1995).
The C<psutils> are still a viable solution if you want to go with the
PDF->PS->PDF route.

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
        my $ppsheet = $self->pages_per_sheet;
        $signature = $maxpage =
          $pages + (($ppsheet - ($pages % $ppsheet)) % $ppsheet);
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
    # if we want a cover, we need to find the index of the last page,
    # and the first undef page, which could be at the beginning of the
    # last signature, so we have to scan the array.
    if ($self->cover) {
        my $last;
        my $firstundef;

        # find the last page
        for (my $i = 0; $i < @pgs; $i++) {
            if ($pgs[$i] and $pgs[$i] == $pages) {
                $last = $i;
            }
        }

        # find the first empty page (inserted by us)
        for (my $i = 0; $i < @pgs; $i++) {
            if (not defined $pgs[$i]) {
                $firstundef = $i;
                last;
            }
        }

        # if we don't find a white page, there is nothing to do
        if (defined $firstundef) {
            # there is an undef, so swap;
            $pgs[$firstundef] = $pgs[$last];
            $pgs[$last] = undef;
        }
    }
    while (@pgs) {
        push @out, [ shift(@pgs), shift(@pgs) ];
    }
    return \@out;
}

sub _do_impose {
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

1;

=head1 SEE ALSO

L<PDF::Imposition>

=cut

