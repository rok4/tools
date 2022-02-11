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
File: pyrolyse.pl

Section: PYROLYSE tool

Synopsis:
    (start code)
    pyrolyse.pl --pyr=path --json=file [--slabs ALL|DATA|MASK] [--tiles ALL|DATA|MASK] [--perfs=file] [--follow-links]
    (end code)
=cut

################################################################################

use warnings;
use strict;

use POSIX qw(locale_h);

# Module
use Getopt::Long;
use Cwd;
use JSON qw( );
use Term::ProgressBar;
use File::Basename;
use Log::Log4perl qw(:easy);
use Time::HiRes;

# My search module
use FindBin qw($Bin);
use lib "$Bin/../lib/perl5";

# My module
use ROK4::Core::PyramidRaster;
use ROK4::Core::PyramidVector;
use ROK4::Core::ProxyStorage;
use ROK4::Core::ProxyPyramid;

################################################################################
# Constantes
use constant TRUE  => 1;
use constant FALSE => 0;

################################################################################
# Version
my $VERSION = '@ROK4_VERSION@';

=begin nd
Variable: options

Contains pyrolyse call options :

    version - To obtain the command's version
    help - To obtain the command's help
    usage - To obtain the command's usage
    
    pyr - To precise the pyramid's descriptor path
    json - To precise the JSON file to write
    perfs - To precise the text file to write read times (only if tiles statistics enabled)
    follow_links - To precise if we want to treat links target like pyramid's slabs

    slabs - To precise if we want slabs statistics (number, mean/min/max size)
    tiles - To precise if we want tiles statistics (number, mean/min/max size)
    
=cut
my %options =
(
    "version"    => 0,
    "help"       => 0,
    "usage"      => 0,

    # Mandatory
    "pyr"  => undef,
    "json"  => undef,
    # Optionnal
    "slabs"  => undef,
    "tiles"  => undef,
    "perfs"  => undef,
    "follow_links"  => FALSE
);

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

    Log::Log4perl->easy_init({
        level => $INFO,
        layout => '%5p : %m (%M) %n'
    });

    # initialization
    if (! main::init()) {
        ERROR("ERROR INITIALIZATION !");
        exit 1;
    }

    # execution
    if (! main::doIt()) {
        ERROR("ERROR EXECUTION !");
        exit 5;
    }
}

=begin nd
Function: init

Checks and stores options, initializes the default logger.
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
            INFO("See documentation here: https://github.com/rok4/rok4");
            exit 0;
        },
        "version|v" => sub { INFO("$VERSION"); exit 0; },
        "usage" => sub {
            INFO("See documentation here: https://github.com/rok4/rok4");
            exit 0;
        },
        
        "pyr=s" => \$options{pyr},
        "json=s" => \$options{json},
        "perfs=s" => \$options{perfs},
        "slabs=s" => \$options{slabs},
        "tiles=s" => \$options{tiles},
        "follow-links" => \$options{follow_links}
    ) or do {
        ERROR("Unappropriate usage");
        ERROR("See documentation here: https://github.com/rok4/rok4");
        exit -1;
    };
    
    ############# PYR
    if (! defined $options{pyr} || $options{pyr} eq "") {
        ERROR("Option 'pyr' not defined !");
        return FALSE;
    }
    
    ############# JSON
    if (! defined $options{json} || $options{json} eq "") {
        ERROR("Option 'json' not defined !");
        return FALSE;
    }

    my $jsonFile = File::Spec->rel2abs($options{json});

    if (-f $jsonFile) {
        ERROR("JSON file already exists : $jsonFile");
        return FALSE;
    }
    $options{json} = $jsonFile;

    my $dir = File::Basename::dirname($jsonFile);
    if (! -d $dir) {
        eval { mkpath([$dir]); };
        if ($@) {
            ERROR("Can not create the JSON file directory '$dir' : $@ !");
            return FALSE;
        }
    }

    ############# PERFS
    if (defined $options{perfs} && $options{perfs} ne "") {
        my $perfsFile = File::Spec->rel2abs($options{perfs});
        $options{perfs} = $perfsFile;

        my $dir = File::Basename::dirname($perfsFile);
        if (! -d $dir) {
            eval { mkpath([$dir]); };
            if ($@) {
                ERROR("Can not create the PERFS file directory '$dir' : $@ !");
                return FALSE;
            }
        }
    }

    
    return TRUE;
}

####################################################################################################
#                                 Group: Process methods                                           #
####################################################################################################

=begin nd
Function: doIt
=cut
sub doIt {

    my $objPyramid = ROK4::Core::ProxyPyramid::load($options{pyr});

    if (! defined $objPyramid) {
        ERROR("Cannot create the Pyramid object (neither raster nor vector)");
        return FALSE;
    }

    my $storageType = $objPyramid->getStorageType();

    if (! ROK4::Core::ProxyStorage::checkEnvironmentVariables($storageType)) {
        ERROR("Environment variable is missing for a $storageType storage");
        return FALSE;
    }

    my $dataRoot = $objPyramid->getDataRoot();
    my $pyramidName = $objPyramid->getName();
    my $slabTilesNumber = $objPyramid->getTilesPerWidth() * $objPyramid->getTilesPerHeight();
    my $tileSizesOffset = ROK4::Core::ProxyStorage::ROK4_IMAGE_HEADER_SIZE + 4 * $slabTilesNumber;

    if (! $objPyramid->loadList()) {
        ERROR("Cannot cache content list of the pyramid");
        return FALSE;
    }

    if (defined $options{perfs}) {
        if (! open PERFS, ">>", $options{perfs}) {
            ERROR("Cannot open file to write (append) readings times : " + $options{perfs});
            return FALSE;
        }
    }

    my $stats = {
        global => {},
        levels => {}
    };

    # Statistiques sur les images
    if ($options{slabs} && ($options{slabs} eq "DATA" || $options{slabs} eq "ALL")) {
        $stats->{global}->{DATA}->{slabs} = {
            size => 0,
            min => undef,
            max => undef,
            average => 0,
            number => 0
        }
    }
    if ($options{tiles} && ($options{tiles} eq "DATA" || $options{tiles} eq "ALL")) {
        $stats->{global}->{DATA}->{tiles} = {
            size => 0,
            min => undef,
            max => undef,
            average => 0,
            number => 0
        }
    }

    # Statistiques sur les masques
    if ($options{slabs} && ($options{slabs} eq "MASK" || $options{slabs} eq "ALL")) {
        $stats->{global}->{MASK}->{slabs} = {
            size => 0,
            min => undef,
            max => undef,
            average => 0,
            number => 0
        }
    }
    if ($options{tiles} && ($options{tiles} eq "MASK" || $options{tiles} eq "ALL")) {
        $stats->{global}->{MASK}->{tiles} = {
            size => 0,
            min => undef,
            max => undef,
            average => 0,
            number => 0
        }
    }

    # Statistiques sur les liens
    if (! $options{follow_links}) {
        $stats->{global}->{links} = 0;
    }

    my $slabs = $objPyramid->getLevelsSlabs();

    # Quantification du travail total
    my $total = 0;
    foreach my $level (keys(%{$slabs})) {
        if (exists $stats->{global}->{DATA}) {
            $total += scalar(values(%{$slabs->{$level}->{DATA}}));
        }
        if (exists $stats->{global}->{MASK}) {
            $total += scalar(values(%{$slabs->{$level}->{MASK}}));
        }
    }
    my $progress = Term::ProgressBar->new({name => 'Content browse...', count => $total});
    my $done = 0;
    my $next = 0;

    # Traitement

    foreach my $type ("DATA", "MASK") {
        
        if (exists $stats->{global}->{$type}) {
            foreach my $level (keys(%{$slabs})) {
                # Traitement des dalles

                if (exists $stats->{global}->{$type}->{slabs}) {
                    $stats->{levels}->{$level}->{$type}->{slabs} = {
                        size => 0,
                        min => undef,
                        max => undef,
                        average => 0,
                        number => 0
                    };
                }

                if (exists $stats->{global}->{$type}->{tiles}) {
                    $stats->{levels}->{$level}->{$type}->{tiles} = {
                        size => 0,
                        min => undef,
                        max => undef,
                        average => 0,
                        number => 0
                    };
                }

                if (! $options{follow_links}) {
                    $stats->{levels}->{$level}->{links} = 0;
                }

                foreach my $parts (values(%{$slabs->{$level}->{$type}})) {

                    if ($parts->{root} ne $dataRoot && ! $options{follow_links}) {
                        # Cette dalle est un lien et on souhaite simplement les compter
                        $stats->{global}->{links}++;
                        $stats->{levels}->{$level}->{links}++;
                        next;
                    }

                    $done++;

                    if ($done >= $next) {
                        $next = $progress->update($done);
                    }

                    my $slabPath = sprintf "%s/%s", $parts->{root}, $parts->{name};
                    if (exists $stats->{global}->{$type}->{slabs}) {
                        $stats->{global}->{$type}->{slabs}->{number}++;
                        $stats->{levels}->{$level}->{$type}->{slabs}->{number}++;

                        my $sSize = ROK4::Core::ProxyStorage::getSize($storageType, $slabPath);
                        if (! defined $sSize) {
                            ERROR("Cannot get slab size ($storageType: $slabPath)");
                            return FALSE;
                        }

                        if (! defined $stats->{levels}->{$level}->{$type}->{slabs}->{min} || $sSize < $stats->{levels}->{$level}->{$type}->{slabs}->{min}) {
                            $stats->{levels}->{$level}->{$type}->{slabs}->{min} = $sSize;
                        }
                        if (! defined $stats->{levels}->{$level}->{$type}->{slabs}->{max} || $sSize > $stats->{levels}->{$level}->{$type}->{slabs}->{max}) {
                            $stats->{levels}->{$level}->{$type}->{slabs}->{max} = $sSize;
                        }

                        $stats->{global}->{$type}->{slabs}->{size} += $sSize;
                        $stats->{levels}->{$level}->{$type}->{slabs}->{size} += $sSize;
                    }

                    if (exists $stats->{global}->{$type}->{tiles}) {

                        my ($readSize, $data);
                        if (defined $options{perfs}) {
                            my $time1 = Time::HiRes::clock_gettime();
                            ($readSize, $data) = ROK4::Core::ProxyStorage::getData($storageType, $slabPath, $tileSizesOffset, $slabTilesNumber * 4);
                            my $time2 = Time::HiRes::clock_gettime();
                            printf PERFS "%s %s\n", $time1, $time2 - $time1;
                        } else {
                            ($readSize, $data) = ROK4::Core::ProxyStorage::getData($storageType, $slabPath, $tileSizesOffset, $slabTilesNumber * 4);
                        }
                        
                        if (! defined $readSize) {
                            ERROR("Cannot get tile size ($storageType: $slabPath)");
                            return FALSE;
                        }

                        my @tSizes = unpack( "i$slabTilesNumber", $data);

                        if (scalar(@tSizes) != $slabTilesNumber) {
                            ERROR(sprintf "Theorical tile number (%s) and sizes count in the slab header (%s) are not equals\n", $slabTilesNumber, scalar(@tSizes));
                            return FALSE;
                        }

                        foreach my $tSize (@tSizes) {
                            if ($tSize != 0) {
                                $stats->{levels}->{$level}->{$type}->{tiles}->{number}++;
                                $stats->{levels}->{$level}->{$type}->{tiles}->{size} += $tSize;
                                $stats->{global}->{$type}->{tiles}->{number}++;
                                $stats->{global}->{$type}->{tiles}->{size} += $tSize;
                                if (! defined $stats->{levels}->{$level}->{$type}->{tiles}->{min} || $tSize < $stats->{levels}->{$level}->{$type}->{tiles}->{min}) {
                                    $stats->{levels}->{$level}->{$type}->{tiles}->{min} = $tSize;
                                }
                                if (! defined $stats->{levels}->{$level}->{$type}->{tiles}->{max} || $tSize > $stats->{levels}->{$level}->{$type}->{tiles}->{max}) {
                                    $stats->{levels}->{$level}->{$type}->{tiles}->{max} = $tSize;
                                }
                            }
                        }
                    }
                }

                if (exists $stats->{global}->{$type}->{slabs}) {
                    if (! defined $stats->{global}->{$type}->{slabs}->{min} || $stats->{levels}->{$level}->{$type}->{slabs}->{min} < $stats->{global}->{$type}->{slabs}->{min}) {
                        $stats->{global}->{$type}->{slabs}->{min} = $stats->{levels}->{$level}->{$type}->{slabs}->{min};
                    }
                    if (! defined $stats->{global}->{$type}->{slabs}->{max} || $stats->{levels}->{$level}->{$type}->{slabs}->{max} > $stats->{global}->{$type}->{slabs}->{max}) {
                        $stats->{global}->{$type}->{slabs}->{max} = $stats->{levels}->{$level}->{$type}->{slabs}->{max};
                    }
                    if ($stats->{levels}->{$level}->{$type}->{slabs}->{number} != 0) {
                        $stats->{levels}->{$level}->{$type}->{slabs}->{average} = $stats->{levels}->{$level}->{$type}->{slabs}->{size} / $stats->{levels}->{$level}->{$type}->{slabs}->{number};
                    }
                }

                if (exists $stats->{global}->{$type}->{tiles}) {
                    if (! defined $stats->{global}->{$type}->{tiles}->{min} || $stats->{levels}->{$level}->{$type}->{tiles}->{min} < $stats->{global}->{$type}->{tiles}->{min}) {
                        $stats->{global}->{$type}->{tiles}->{min} = $stats->{levels}->{$level}->{$type}->{tiles}->{min};
                    }
                    if (! defined $stats->{global}->{$type}->{tiles}->{max} || $stats->{levels}->{$level}->{$type}->{tiles}->{max} > $stats->{global}->{$type}->{tiles}->{max}) {
                        $stats->{global}->{$type}->{tiles}->{max} = $stats->{levels}->{$level}->{$type}->{tiles}->{max};
                    }
                    if ($stats->{levels}->{$level}->{$type}->{tiles}->{number} != 0) {
                        $stats->{levels}->{$level}->{$type}->{tiles}->{average} = $stats->{levels}->{$level}->{$type}->{tiles}->{size} / $stats->{levels}->{$level}->{$type}->{tiles}->{number};
                    }
                }
            }

            if (exists $stats->{global}->{$type}->{slabs}) {
                if ($stats->{global}->{$type}->{slabs}->{number} != 0) {
                    $stats->{global}->{$type}->{slabs}->{average} = $stats->{global}->{$type}->{slabs}->{size} / $stats->{global}->{$type}->{slabs}->{number};
                }
            }
            if (exists $stats->{global}->{$type}->{tiles}) {
                if ($stats->{global}->{$type}->{tiles}->{number} != 0) {
                    $stats->{global}->{$type}->{tiles}->{average} = $stats->{global}->{$type}->{tiles}->{size} / $stats->{global}->{$type}->{tiles}->{number};
                }
            }
        }

    }

    if (defined $options{perfs}) {
        close(PERFS);
    }


    if (! open JSON, ">", $options{json} ) {
        ERROR(sprintf "Cannot open the JSON file %s to write", $options{json});
        return FALSE;
    }
    print JSON JSON::to_json($stats, {pretty => 1});
    close(JSON);

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
