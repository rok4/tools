#!/usr/bin/perl -w

use ExtUtils::MakeMaker;

sub MY::postamble {
    return <<'ECHO_VERSION';
injectversion ::
	$(NOECHO) sed -i "s#@VERSION@#$(VERSION)#" $(INST_SCRIPT)/*.pl

ECHO_VERSION
}

WriteMakefile(
    # version du package complet
    NAME        => "ROK4TOOLS",
    # install to INSTALL_BASE/bin
    EXE_FILES   => [
        'bin/convert2json.pl',
        'bin/create-layer.pl',
        'bin/pyrolyse.pl',
        'bin/sup-pyr.pl',
        'bin/tms-toolbox.pl'
    ],
    BUILD_REQUIRES => { 
        "ExtUtils::MakeMaker" => 0
    },
    # ack --ignore-dir=core -h "^use [A-Z]" ./ | cut -d' ' -f2 | sed -r "s#;##" | sort | uniq | sed -r "s/(.+)/\"\1\" => 0,/"
    PREREQ_PM => {
        "Cwd" => 0,
        "Data::Dumper" => 0,
        "ExtUtils::MakeMaker" => 0,
        "File::Basename" => 0,
        "FindBin" => 0,
        "Getopt::Long" => 0,
        "JSON" => 0,
        "Log::Log4perl" => 0,
        "POSIX" => 0,
        "ROK4::Core::Base36" => 0,
        "ROK4::Core::ProxyGDAL" => 0,
        "ROK4::Core::ProxyPyramid" => 0,
        "ROK4::Core::ProxyStorage" => 0,
        "ROK4::Core::PyramidRaster" => 0,
        "ROK4::Core::PyramidVector" => 0,
        "ROK4::Core::TileMatrixSet" => 0,
        "ROK4::Core::Utils" => 0,
        "Term::ProgressBar" => 0,
        "Time::HiRes" => 0
    }
);
