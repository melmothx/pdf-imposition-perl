use 5.010001;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'PDF::Imposition',
    AUTHOR           => q{Marco Pessotto <melmothx@gmail.com>},
    VERSION_FROM     => 'lib/PDF/Imposition.pm',
    ABSTRACT_FROM    => 'lib/PDF/Imposition.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.010001,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Try::Tiny' => 0,
        'CAM::PDF' => 1.58,
        'PDF::API2' => 2.019,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'PDF-Imposition-*' },
);
