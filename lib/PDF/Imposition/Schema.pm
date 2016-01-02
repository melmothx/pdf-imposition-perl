package PDF::Imposition::Schema;
use strict;
use warnings;

use File::Basename qw/fileparse/;
use File::Spec;
use CAM::PDF;
use PDF::API2;
use File::Temp ();
use File::Copy;
use POSIX ();

=head1 NAME

PDF::Imposition::Schema - Base class for the imposition schemas.

=head1 SYNOPSIS

Please don't use this class directly, but use L<PDF::Imposition> or
the right schema class, which inherit from this (which in turns
defines the shared methods). B<This class does not do anything useful
by itself, but only provides some shared methods>.

    use PDF::Imposition;
    my $imposer = PDF::Imposition->new(file => "test.pdf",
                                       # either use 
                                       outfile => "out.pdf",
                                       # or suffix
                                       suffix => "-2up"
                                      );
    $imposer->impose;
or 

    use PDF::Imposition;
    my $imposer = PDF::Imposition->new();
    $imposer->file("test.pdf");
    
    $imposer->outfile("out.pdf");
    # or
    $imposer->suffix("-imp");

    $imposer->impose;
  
=cut





=head1 METHODS

=head2 Constructor 

=head3 new(file => "file.pdf", suffix => "-imp", cover => 0, [...])

Costructor. Options should be passed as list. The options are the same
of the read-write accessors describe below, so passing
C<< $self->file("file.pdf") >> is exactly the same of passing
C<< $self->new(file => "file.pdf") >>.

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

=head2 Read/write accessors

All the following accessors accept an argument, which sets the
value.

=head3 file

Unsurprisingly, the input file, which must exist.

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
        $self->{_tmp_dir} = File::Temp->newdir(CLEANUP => 1);
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
        my ($name, $path, $suffix) = fileparse($self->file, qr{\.pdf}i);
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

This option is ignored for 2x4x2 and 2side schemas. Often it happens
that we want the last page of the pdf to be the last one on the
physical booklet after folding. If C<cover> is set to a true value,
the last page of the logical pdf will be placed on the last page of
the last signature.

Individual schema implementations are in charge to check and act on this setting.

Es.

  $imposer->cover(1);

=cut

sub cover {
    my $self = shift;
    if (@_ == 1) {
        $self->{cover} = shift;
    }
    return $self->{cover};
}



=head2 Internal accessors

The following methods are used internally but documented for schema's
authors.

L<CAM::PDF> is used to get the properties, and L<PDF::API2> to arrange
the pages. L<CAM::PDF> is also used to convert PDF 1.6-1.5 to PDF
v1.4, which it's the only version L<PDF::API2> understands.

=head3 dimensions

Returns an hashref with the original pdf dimensions in points.

  { w => 800, h => 600 }

=head3 orig_width

=head3 orig_height

=head3 total_pages

Returns the number of pages


=cut

sub dimensions {
    my $self = shift;
    unless ($self->{_dimensions}) {
        my $pdf = $self->in_pdf_obj;
        my ($x, $y, $w, $h) = $pdf->openpage(1)->get_mediabox; # use the first page
        warn $self->file . "use x-y offset, cannot proceed safely" if ($x + $y);
        die "Cannot retrieve paper dimensions" unless $w && $h;
        $self->{_dimensions} = { w => sprintf('%.2f', $w),
                                 h => sprintf('%.2f', $h) };
    }
    # return a copy
    return { %{$self->{_dimensions}} };
}

sub total_pages {
    my $self = shift;
    unless ($self->{_total_orig_pages}) {
        my $pdf = $self->in_pdf_obj;
        my $count = 0;
        while ($pdf->openpage($count + 1)) {
            $count++;
        }
        $self->{_total_orig_pages} = $count;
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
        my ($basename, $path, $suff) = fileparse($self->file, qr{\.pdf}i);
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
            my $tmpfile_copy =
              File::Spec->catfile($self->_tmp_dir,
                                  $basename . "-v14" . $suff);
            $src->cleansave();
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
        my $pdf = PDF::API2->new();
        my ($basename, $path, $suff) = fileparse($self->file, qr{\.pdf}i);
        $pdf->info(
                   Creator => 'PDF::Imposition',
                   Producer => 'PDF::API2',
                   Title => $basename,
                   CreationDate => $self->_orig_file_timestamp,
                   ModDate => $self->_now_timestamp,
                  );
        $self->{_output_pdf_obj} = $pdf;
    }
    return $self->{_output_pdf_obj};
}

=head3 get_imported_page($pagenumber)

Retrieve the page form object from the input pdf to the output pdf,
and return it. The method return undef if the page is out of range.

=cut


sub get_imported_page {
    my ($self, $page) = @_;
    if ((!defined $page) || ($page <= 0) || ($page > $self->total_pages)) {
        return undef;
    }
    return  $self->out_pdf_obj->importPageIntoForm($self->in_pdf_obj, $page)
}

=head3 impose

Do the job and leave the output in C<< $self->outfile >>, cleaning up
the internal objects.

=cut

sub impose {
    my $self = shift;
    my $out = $self->_do_impose;
    $self->in_pdf_obj->end;
    $self->out_pdf_obj->end;
    return $out;
}

sub _orig_file_timestamp {
    my $self = shift;
    my $mtime = (stat($self->file))[9];
    return $self->_format_timestamp($mtime);
}

sub _now_timestamp {
    return shift->_format_timestamp(time());
}

sub _format_timestamp {
    my ($self, $epoc) = @_;
    return POSIX::strftime(q{%Y%m%d%H%M%S+00'00'}, localtime($epoc));
}

sub DESTROY {
    my $self = shift;
    foreach my $f (qw/_output_pdf_obj _input_pdf_obj/) {
        if ($self->{$f}) {
            $self->{$f}->end;
            delete $self->{$f};
        }
    }
}

1;

=head1 SEE ALSO

L<PDF::Imposition>

=cut


