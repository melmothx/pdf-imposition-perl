package PDF::Imposition::Schema1repeat2top;
use strict;
use warnings;
use base qw/PDF::Imposition::Schema/;

=head1 NAME

PDF::Imposition::Schema1repeat2top - put two identical pages one on the top of each other.

=head1 SYNOPSIS

    use PDF::Imposition::Schema1repeat2top;
    my $imposer = PDF::Imposition::Schema1repeat2top->new(
                                                          file => "test.pdf",
                                                          output => "out.pdf",
                                                         );
    $imposer->impose;

=head1 SCHEMA EXPLANATION

     +-----+    +-----+
     |     |    |     |
     |  1  |    |  2  |
     |     |    |     |
     +-----+    +-----+
     |     |    |     |
     |  1  |    |  2  |
     |     |    |     |
     +-----+    +-----+

The same logical page is inserted twice, one on the top of each other,
on the same sheet, nothing else.

=cut


sub _do_impose {
    my $self = shift;
    $self->out_pdf_obj->mediabox(
                                 $self->orig_width,
                                 $self->orig_height * 2,
                                );
    foreach my $pageno (1..$self->total_pages) {
        my ($page, $gfx, $chunk);
        $page = $self->out_pdf_obj->page;
        $gfx = $page->gfx;
        $chunk = $self->get_imported_page($pageno);
        $gfx->formimage($chunk, 0, 0) if $chunk;
        $chunk = $self->get_imported_page($pageno);
        $gfx->formimage($chunk, 0, $self->orig_height) if $chunk;
    }
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}

=head1 INTERNALS

=head2 pages_per_sheet

Returns 4.

=cut

sub pages_per_sheet { 4 };


1;
