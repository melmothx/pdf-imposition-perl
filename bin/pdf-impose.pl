#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use PDF::Imposition;
my $file = $ARGV[0];
die "Missing input" unless $file;
die "$file is not a file" unless -f $file;
my $imposer = PDF::Imposition->new(file => $file);
$imposer->impose;


