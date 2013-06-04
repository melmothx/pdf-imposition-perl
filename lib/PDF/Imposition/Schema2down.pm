package PDF::Imposition::Schema2down;
use strict;
use warnings FATAL => 'all';

use base qw/PDF::Imposition::Schema2up/;

=head3 impose

Do the job and leave the output in C<$self->outfile>

=cut

sub impose {
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
        $gfx->transform (
                          -translate => [$self->orig_height, 0],
                          -rotate => 90
                         );
        if (defined $left) {
            my $lpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $left);
            $gfx->formimage($lpage);
        }
        if (defined $right) {
            my $rpage = $self->out_pdf_obj
              ->importPageIntoForm($self->in_pdf_obj, $right);
            $gfx->formimage($rpage, 0, 0 - $self->orig_height);
        }
    }
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}

1;
