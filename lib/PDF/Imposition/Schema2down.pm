package PDF::Imposition::Schema2down;
use strict;
use warnings FATAL => 'all';

use base qw/PDF::Imposition::Schema2up/;

=head1 NAME

PDF::Imposition::Schema2down - Imposition schema 2down (booklet with binding on the top)

=head1 SYNOPSIS

This class inherit everything from L<PDF::Imposition::Schema2up> and
only alters the C<impose> method to rotate the pages by 90 degrees.
Please refer to the parent class for method documentation.

=head1 SCHEMA EXPLANATION

First go and read the schema explanation in
L<PDF::Imposition::Schema2up> (or better, the whole documentation).
It's the same dynamic kind of imposition.

The only difference is that each I<logical> page is rotated by 90
degrees counter-clockwise, so a signature of 4 pages looks so:

        +------+------+   +------+------+   
        |   4  |  1   |   |   2  |  3   |   
        +------+------+   +------+------+   

Now, showing the number rotated by 90 degrees is a bit complicated in
ASCII-art, but each right logical page is B<rotated
counter-clockwise>, while the left logical page is rotated clockwise,
so you have to bind it on the short edge (and the final product will
look much more like a notepad than a booklet, as the binding will fall
on the top edge).

I find this schema odd, but I provide it nevertheless.

=cut

sub _do_impose {
    my $self = shift;
    $self->out_pdf_obj->mediabox(
                                 $self->orig_height * 2,
                                 $self->orig_width,
                                );
    my $seq = $self->page_sequence_for_booklet;
    foreach my $p (@$seq) {
        # loop over the pages
        my $left = $p->[0];
        my $right = $p->[1];
        my $page = $self->out_pdf_obj->page();
        my $gfx = $page->gfx();

        $gfx->transform ( -translate => [ 0 , $self->orig_width],
                          -rotate => 270 );
        if (defined $left) {
            my $lpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $left);
            $gfx->formimage($lpage);
        }

        $gfx->transform ( -translate => [ $self->orig_width, 2 * $self->orig_height ],
                          -rotate => 180 );

        if (defined $right) {
            my $rpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $right);
            $gfx->formimage($rpage);
        }
    }
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}

=head2 cropmark_options

Set twoside to true and top to false (where the binding is)

=cut

sub cropmarks_options {
    my %opts = (
                twoside => 0, # right now we don't do shifting on the top
                top => 0,
                bottom => 1,
                inner => 1,
                outer => 1,
               );
    return %opts;
}


1;

=head1 SEE ALSO

L<PDF::Imposition>

=cut


