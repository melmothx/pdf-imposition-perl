#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use PDF::Imposition;
use Getopt::Long;

my ($signature, $help, $suffix);

my $opts = GetOptions (
                       'signature|sig|s=s' => \$signature,
                       'help|h' => \$help,
                       'suffix=s' => \$suffix,
                      );
my ($file, $outfile) = @ARGV;

if ($help) {
    give_help();
}


die "Missing input" unless $file;
die "$file is not a file" unless -f $file;
my $imposer = PDF::Imposition->new(file => $file);
if ($signature) {
    $imposer->signature($signature);
}
if ($outfile) {
    $imposer->outfile($outfile);
}
if ($suffix) {
    $imposer->suffix('-' . $suffix);
}
warn "Output on " . $imposer->outfile . "\n";
if (-f $imposer->outfile) {
    unlink $imposer->outfile or die "Couldn't remove old output! $!";
}
$imposer->cover(1);
$imposer->impose;
# and that's all


sub give_help {
    print << "EOF";

Usage: $0 infile.pdf [outfile.pdf]

Options:

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
