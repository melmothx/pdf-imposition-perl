#!perl -T
use 5.010001;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'PDF::Imposition' ) || print "Bail out!\n";
}

diag( "Testing PDF::Imposition $PDF::Imposition::VERSION, Perl $], $^X" );
