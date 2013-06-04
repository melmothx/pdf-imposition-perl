package PDF::Imposition::Schema;
use strict;
use warnings;

use File::Basename qw/fileparse/;
use File::Spec;
use CAM::PDF;
use PDF::API2;
use File::Temp ();
use File::Copy;


=head1 SUBROUTINES/METHODS

=head2 new(file => "file.pdf", suffix => "-imp", cover => 0, [...])

Costructor. Options should be passed as list. The options are the same
of the above accessors, so passing C<$self->file("file.pdf")> is
exactly the same of passing C<$self->new(file => "file.pdf")>.

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


=head3 cover

This option is only used when the booklet schema is asked, i.e., when
a variable signature is needed. Often it happens that we want the last
page of the pdf to be the last on the physical booklet. The original
algorithm just fills the signature with blank pages. If C<cover> is
set to a true value, the last page of the logical pdf will be placed
on the last page of the last signature.

=cut

sub cover {
    my $self = shift;
    if (@_ == 1) {
        $self->{cover} = shift;
    }
    return $self->{cover};
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

1;
