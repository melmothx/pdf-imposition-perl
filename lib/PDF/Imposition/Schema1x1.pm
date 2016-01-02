package PDF::Imposition::Schema1x1;
use strict;
use warnings;
use base "PDF::Imposition::Schema2up";

=head1 NAME

PDF::Imposition::Schema1x1 - 1:1 Imposition schema

=head2 SYNOPSIS

    use PDF::Imposition::Schema1x1;
    my $imposer = PDF::Imposition::Schema2up->new(
                                                  signature => "10-20",
                                                  file => "test.pdf",
                                                  output => "out.pdf",
                                                  cover => 1,
                                                  pages_per_sheet => 4,
                                                 );
    $imposer->impose;

The output pdf will be in C<$imposer->output>

=head1 SCHEMA EXPLANATION

This is a 1:1 imposition schema, meaning that apparently doesn't do anything.

The purpose of this module is to do 2 things:

=over 4

=item Convert the PDF to version 1.4, if not already so.

=item Handle the signature rounding and optimization

This for example means that a pdf with 6 pages will end up with 8
pages (6 + 2 empty), and if you pass the C<cover> option with a true
value, you'll get the sixth page as page 8.

Also you can get the computed value calling C<computed_signature> and
the total output pages with C<total_output_pages>.

=back

If you don't need any of this, you don't have any reason to use this
module.

This class inherit everything from L<PDF::Imposition::Schema2up>, so
refer to the documentation of that module for a full explanation of
the C<signature>, C<cover> and C<pages_per_sheet> explanation.

=cut

sub _do_impose {
    my $self = shift;
    $self->out_pdf_obj->mediabox(
                                 $self->orig_width,
                                 $self->orig_height,
                                );
    my $total_pages = $self->total_pages;
    my $signature = $self->computed_signature;
    my $max_page = $self->total_output_pages;
    my $needed = ($max_page - $total_pages);
    my @sequence = (1 .. $total_pages);
    if ($needed) {
        my $last = pop @sequence;
        while ($needed > 0) {
            push @sequence, undef;
            $needed--;
        }
        push @sequence, $last;
    }
    die "Something went off" if @sequence != $max_page;
    foreach my $pageno (@sequence) {
        my $page = $self->out_pdf_obj->page;
        my $gfx = $page->gfx;
        if (my $chunk = $self->get_imported_page($pageno)) {
            $gfx->formimage($chunk, 0, 0);
        }
    }
    $self->out_pdf_obj->saveas($self->outfile);
    return $self->outfile;
}

1;
