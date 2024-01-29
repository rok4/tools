#!/usr/bin/env perl

use strict;
use warnings;

use Log::Log4perl qw(:easy);

use ROK4::Core::TileMatrixSet;
use ROK4::Core::ProxyPyramid;

Log::Log4perl->easy_init({
    level => $INFO,
    layout => '%5p : %m (%M) %n'
});

my $pyr_file = shift(@ARGV);

my $pyramid = ROK4::Core::ProxyPyramid::load($pyr_file);

if (! defined $pyramid) {
    ERROR("Cannot create the Pyramid object (neither raster nor vector)");
    exit(1);
}

$pyramid->writeDescriptor();

exit(0);
