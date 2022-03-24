#!/usr/bin/env perl
# Copyright © (2011) Institut national de l'information
#                    géographique et forestière
#
# Géoportail SAV <contact.geoservices@ign.fr>
#
# This software is a computer program whose purpose is to publish geographic
# data using OGC WMS and WMTS protocol.
#
# This software is governed by the CeCILL-C license under French law and
# abiding by the rules of distribution of free software.  You can  use,
# modify and/ or redistribute the software under the terms of the CeCILL-C
# license as circulated by CEA, CNRS and INRIA at the following URL
# "http://www.cecill.info".
#
# As a counterpart to the access to the source code and  rights to copy,
# modify and redistribute granted by the license, users are provided only
# with a limited warranty  and the software's author,  the holder of the
# economic rights,  and the successive licensors  have only  limited
# liability.
#
# In this respect, the user's attention is drawn to the risks associated
# with loading,  using,  modifying and/or developing or reproducing the
# software by the user in light of its specific status of free software,
# that may mean  that it is complicated to manipulate,  and  that  also
# therefore means  that it is reserved for developers  and  experienced
# professionals having in-depth computer knowledge. Users are therefore
# encouraged to load and test the software's suitability as regards their
# requirements in conditions enabling the security of their systems and/or
# data to be ensured and,  more generally, to use and operate it in the
# same conditions as regards security.
#
# The fact that you are presently reading this means that you have had
#
# knowledge of the CeCILL-C license and that you accept its terms.

################################################################################

=begin nd
File: create-layer.pl

Section: CREATE-LAYER tool

Synopsis:
    (start code)
    perl create-layer.pl --pyramid=<file> --tmsdir=<directory> [--title=<string>] [--abstract=<string>]
    (end code)

Debug tool allowing to write a default layer descriptor to the standard output, from a pyramid descriptor.

CRS' list :
    - data's CRS
    - CRS:84
    - IGNF:WGS84G
    - EPSG:3857
    - EPSG:4258

(see ROK4GENERATION/layer.png)
=cut

################################################################################

use warnings;
use strict;

use POSIX qw(locale_h);

# Module
use Log::Log4perl qw(:easy);
use Getopt::Long;
use File::Basename;
use Cwd;
use JSON qw( );

# My search module
use FindBin qw($Bin);
use lib "$Bin/../lib/perl5";

# My module
use ROK4::Core::TileMatrixSet;
use ROK4::Core::ProxyPyramid;

################################################################################
# Constantes
use constant TRUE  => 1;
use constant FALSE => 0;

################################################################################
# Version
my $VERSION = '@VERSION@';

=begin nd
Variable: options

Contains create-layer call options :
    version - To obtain the command's version
    help - To obtain the command's help
    usage - To obtain the command's usage
    
    pyramid - To precise the pyramid's descriptor path
    title - To precise the layer's title (optionnal)
    abstract - To precise the layer's abstract (optionnal)
=cut
my %options =
(
    "version"    => 0,
    "help"       => 0,
    "usage"      => 0,

# Mandatory
    "pyramid"  => undef,
    "tmsdir" => undef,

# Optionnal
    "title" => undef,
    "abstract" => undef,
);

################################################################################

####################################################################################################
#                                         Group: Functions                                         #
####################################################################################################

=begin nd
Function: main

Main method.

See Also:
    <init>, <doIt>
=cut
sub main {
    
    # initialization
    if (! main::init()) {
        print STDERR "ERROR INITIALIZATION !\n";
        exit 1;
    }

    # execution
    if (! main::doIt()) {
        print STDERR "ERROR EXECUTION !\n";
        exit 5;
    }
}

=begin nd
Function: init

Checks and stores options, initializes the default logger. Checks TMS directory and the pyramid's descriptor file.
=cut
sub init {

    # init Getopt
    local $ENV{POSIXLY_CORRECT} = 1;

    Getopt::Long::config qw(
        default
        no_autoabbrev
        no_getopt_compat
        require_order
        bundling
        no_ignorecase
        permute
    );

    # init Options
    GetOptions(
        "help|h" => sub {
            printf("CREATE-LAYER : version [%s]\n", $VERSION);
            printf "See documentation here: https://github.com/rok4/rok4\n" ;
            exit 0;
        },
        "version|v" => sub { 
            printf("CREATE-LAYER : version [%s]\n", $VERSION);
            exit 0;
        },
        "usage" => sub {
            printf("CREATE-LAYER : version [%s]\n", $VERSION);
            printf "See documentation here: https://github.com/rok4/rok4\n" ;
            exit 0;
        },
        
        "pyramid=s" => \$options{pyramid},
        "title=s" => \$options{title},
        "abstract=s" => \$options{abstract}
    ) or do {
        printf("CREATE-LAYER : version [%s]\n", $VERSION);
        printf "Unappropriate usage\n";
        printf "See documentation here: https://github.com/rok4/rok4\n";
        exit -1;
    };
    
    # logger by default at runtime
    Log::Log4perl->easy_init({
        level => "ERROR",
        layout => '%5p : %m (%M) %n'
    });

    ############# pyramid
    if (! defined $options{pyramid} || $options{pyramid} eq "") {
        ERROR("Option 'pyramid' not defined !");
        return FALSE;
    }

    ############# title
    if (! defined $options{"title"} || $options{"title"} eq "") {
        $options{"title"} = File::Basename::basename($options{pyramid}, ".json");
    }

    ############# abstract
    if (! defined $options{"abstract"} || $options{"abstract"} eq "") {
        $options{"abstract"} = sprintf "Diffusion de la donnée %s", File::Basename::basename($options{pyramid}, ".pyr");
    }

    return TRUE;
}

####################################################################################################
#                                 Group: Process methods                                           #
####################################################################################################

=begin nd
Function: doIt

We extract all needed informations from the pyramid's descriptor

Use classes :
    - <ROK4::Core::ProxyPyramid>
    - <ROK4::Core::TileMatrixSet>
=cut
sub doIt {
    
    my $pyramid = ROK4::Core::ProxyPyramid::load($options{pyramid});

    if (! defined $pyramid) {
        ERROR("Cannot create the Pyramid object (neither raster nor vector)");
        return FALSE;
    }

    INFO("Pyramid's type : ".ref ($pyramid));

    my $layer_json_object = {
        title => $options{title},
        abstract => $options{abstract},
        keywords => [$pyramid->getTileMatrixSet()->getName(), $pyramid->getFormatCode()],
        tms => {
            authorized => JSON::true
        }
    };

    if (ref ($pyramid) eq "ROK4::Core::PyramidRaster") { 
        
        my $interpolation = $pyramid->getInterpolation();
        if ($interpolation eq "lanczos") {
            $layer_json_object->{resampling} = "${interpolation}_2";
        } else {
            $layer_json_object->{resampling} = "$interpolation";
        }

        $layer_json_object->{styles} = ["normal"];

        $layer_json_object->{wms} = {
            authorized => JSON::true,
            crs => [ $pyramid->getTileMatrixSet()->getSRS(), "CRS:84", "IGNF:WGS84G", "EPSG:3857", "EPSG:4258", "EPSG:4326" ]
        };
        $layer_json_object->{wmts} = {
            authorized => JSON::true
        };
    }

    $layer_json_object->{pyramids} = [{
        top_level => $pyramid->getTopID(),
        bottom_level => $pyramid->getBottomID(),
    }];

    my $storageType = $pyramid->getStorageType();
    if ($storageType eq "FILE") {
        $layer_json_object->{pyramids}->[0]->{path} = $pyramid->getDescriptorPath();
    }
    elsif ($storageType eq "S3") {
        $layer_json_object->{pyramids}->[0]->{path} = $pyramid->getName() . ".json";
        $layer_json_object->{pyramids}->[0]->{bucket_name} = $pyramid->getDataBucket();
    }
    elsif ($storageType eq "SWIFT") {
        $layer_json_object->{pyramids}->[0]->{path} = $pyramid->getName() . ".json";
        $layer_json_object->{pyramids}->[0]->{container_name} = $pyramid->getDataContainer();
    }
    elsif ($storageType eq "CEPH") {
        $layer_json_object->{pyramids}->[0]->{path} = $pyramid->getName() . ".json";
        $layer_json_object->{pyramids}->[0]->{pool_name} = $pyramid->getDataPool();
    }

    print JSON::to_json($layer_json_object, {pretty => 1});

    return TRUE;
}

################################################################################

BEGIN {}
INIT {}

main;
exit 0;

END {}

################################################################################

1;
__END__

=begin nd
Section: Details

Group: Command's options

    --help - Display the link to the technic documentation.

    --usage - Display the link to the technic documentation.

    --version - Display the tool version.

    --pyramid - Pyramid's descriptor file, defining data used by the layer. Mandatory.

    --resampling - Optionnal, interpolation kernel used by ROK4 to resample images. lanczos_4 by default.
    
    --style - Optionnal, style to apply to images. normal by default.

=cut
