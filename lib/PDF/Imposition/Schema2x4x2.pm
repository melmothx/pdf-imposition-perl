package PDF::Imposition::Schema2x4x2;
use strict;
use warnings;
use base qw/PDF::Imposition::Schema/;

=head1 NAME PDF::Imposition::Schema2x4x2

=head1 SYNOPSIS



=head1 METHODS

=over 4

=item  impose

Do the job and leave the output in C<$self->outfile>

=back

=cut

sub impose {
    my $self = shift;
    # set the mediabox doubling them
    $self->out_pdf_obj->mediabox(
                                 $self->orig_width * 2,
                                 $self->orig_height * 2,
                                );
    # here we work with fixed signatures of 16, with the module
    my $total = $self->total_pages;
    my ($page, $gfx, $chunk);
    my @pages = (1..$total);

    # loop over the pages and compose the 4 physical pages
    while (@pages) {
        my ($p1,  $p2,  $p3,  $p4,
            $p5,  $p6,  $p7,  $p8,
            $p9,  $p10, $p11, $p12,
            $p13, $p14, $p15, $p16) = splice @pages, 0, 16;
        # initialize
        $self->_compose_quadruple($p16, $p1, $p8, $p9);
        $self->_compose_quadruple($p2, $p15, $p10, $p7);
        $self->_compose_quadruple($p14, $p3, $p6, $p11);
        $self->_compose_quadruple($p4, $p13, $p12, $p5);
    }
    
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}

sub _compose_quadruple {
    my ($self, @seq) = @_;
    my $chunk;
    my $page = $self->out_pdf_obj->page;
    my $gfx = $page->gfx;

    $chunk = $self->get_imported_page($seq[0]);
    $gfx->formimage($chunk, 0, 0) if $chunk;

    $chunk = $self->get_imported_page($seq[1]);
    $gfx->formimage($chunk, $self->orig_width, 0) if $chunk;

    # translate
    $gfx->transform (
                     -translate => [$self->orig_width  * 2,
                                    $self->orig_height * 2],
                     -rotate => 180,
                    );

    $chunk = $self->get_imported_page($seq[2]);
    $gfx->formimage($chunk, 0, 0) if $chunk;
    
    $chunk = $self->get_imported_page($seq[3]);
    $gfx->formimage($chunk, $self->orig_width, 0) if $chunk;
}

1;
