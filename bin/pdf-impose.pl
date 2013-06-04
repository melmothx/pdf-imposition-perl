#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use PDF::Imposition;
use Getopt::Long;

my ($signature, $help, $suffix,$cover);

my $schema = '2up';

my $opts = GetOptions (
                       'signature|sig|s=s' => \$signature,
                       'help|h' => \$help,
                       'suffix=s' => \$suffix,
                       'cover' => \$cover,
                       'schema=s' => \$schema,
                      );
my ($file, $outfile) = @ARGV;

if ($help) {
    give_help();
}


die "Missing input" unless $file;
die "$file is not a file" unless -f $file;
my $imposer = PDF::Imposition->new(file => $file, schema => $schema);
if ($signature) {
    $imposer->signature($signature);
}
if ($outfile) {
    $imposer->outfile($outfile);
}
if ($suffix) {
    $imposer->suffix('-' . $suffix);
}
if ($cover) {
    $imposer->cover(1);
}
warn "Output on " . $imposer->outfile . "\n";
if (-f $imposer->outfile) {
    unlink $imposer->outfile or die "Couldn't remove old output! $!";
}
$imposer->impose;
# and that's all
print "Imposed PDF left in " . $imposer->outfile . "\n";

sub give_help {
    print << "EOF";

Usage: $0 infile.pdf [outfile.pdf]

Options:

  --schema <string>
    The schema to use: defaults to 2up

  --cover
    Boolean

  --signature | --sig | -s <num>
    <num> must be a multiple of 4.

  --suffix <string>
    defaults to '-imp'

  --help
    show this help

If outfile is not provided, it will use the suffix to create the
output filename.


EOF
    exit 2;
}
