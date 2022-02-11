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

INFO("Pyramid's type : ".ref ($pyramid));

if (! $pyramid->bindTileMatrixSet("../../../config/tileMatrixSet")) {
    ERROR("Can not bind the TMS to the pyramid");
    exit(1);
}

$pyramid->writeDescriptor();

exit(0);