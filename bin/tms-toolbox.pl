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
File: tms-toolbox.pl
=cut

################################################################################

use warnings;
use strict;

use POSIX qw(locale_h);

# Module
use Getopt::Long;
use File::Basename;
use Cwd;
use Term::ProgressBar;

# My search module
use FindBin qw($Bin);
use lib "$Bin/../lib/perl5";

# My module
use ROK4::Core::TileMatrixSet;
use ROK4::Core::Utils;
use ROK4::Core::Base36;
use ROK4::Core::ProxyGDAL;

################################################################################
# Constantes
use constant TRUE  => 1;
use constant FALSE => 0;

################################################################################
# Version
my $VERSION = '@VERSION@';

=begin nd
Variable: options

Contains tms-toolbox call options
=cut
my %options =
(
    # Mandatory
    "from" => undef,
    "to" => undef,
    "tms" => undef,

    # Optionnal
    "storage" => undef,
    "slabsize" => undef,
    "level" => undef,
    "above" => undef,
    "buffer" => undef,
    "progress" => undef
);


=begin nd
Variable: help   
=cut
my $help = "tms-toolbox.pl --tms <TMS name> [--slabsize <INT>x<INT>] [--storage FILE[:<INT>]|CEPH|S3|SWIFT] [--level <STRING>] [--above <STRING>] [--ratio <INT>] --from <STRING> --to <STRING> [--progress] [--buffer <INT>]";


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
        exit 1;
    }

    # execution
    if (! main::doIt()) {
        exit 5;
    }

}

=begin nd
Variable: intputs_outputs

Hash containing authorized types, input or output
=cut
my %intputs_outputs = (
    BBOX => 1,
    BBOXES_LIST => 1,
    GEOM_FILE => 1,
    GEOM => 1,
    GETMAP_PARAMS => 1,
    GETTILE_PARAMS => 1,
    POINT => 1,
    PYRAMID_LIST => 1,
    SLAB_INDICE => 1,
    SLAB_INDICES => 1,
    SLAB_INDICES_LIST => 1,
    SLAB_INFO => 1,
    SLAB_PATH => 1,
    SLAB_PATHS => 1,
    SLABS_COUNT => 1,
    SQL_FILE => 1,
    TFW_FILE => 1,
    TILE_INDICE => 1,
    TILE_INFO => 1
);

=begin nd
Function: parseFromTo
=cut
sub parseFromTo {
    my $string = shift;
    my $parsed = {};

    if ($string =~ m/^([^:]+)(:(\S+))?$/) {
        $parsed->{type} = $1;
        my $value = $3;

        if (! exists $intputs_outputs{$parsed->{type}}) {
            printf STDERR "Unknown type '%s'\n", $parsed->{type};
            return undef;
        }

        #################### BBOX

        elsif ($parsed->{type} eq "BBOX") {
            if (defined $value) {
                if (! ROK4::Core::Utils::isBbox($value)) {
                    print STDERR "Value have to respect format BBOX:<XMIN>,<YMIN>,<XMAX>,<YMAX>\n";
                    return undef;
                }
                my @bb = split(/,/,$value);
                $parsed->{bbox} = \@bb;
            } else {
                print STDERR "Value have to respect format BBOX:<XMIN>,<YMIN>,<XMAX>,<YMAX>\n";
                return undef;
            }
        }

        #################### BBOXES_LIST

        elsif ($parsed->{type} eq "BBOXES_LIST") {
            if (! defined $value) {
                print STDERR "Value have to respect format BBOXES_LIST:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }

        #################### GEOM_FILE

        elsif ($parsed->{type} eq "GEOM_FILE") {

            if (! defined $value) {
                print STDERR "Value have to respect format GEOM_FILE:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }

        #################### GEOM

        elsif ($parsed->{type} eq "GEOM") {
            if (defined $value) {
                print STDERR "Value have to respect format GEOM\n";
                return undef;                
            } 
        }

        #################### GETMAP_PARAMS

        elsif ($parsed->{type} eq "GETMAP_PARAMS") {
            if (defined $value) {
                print STDERR "Value have to respect format GETMAP_PARAMS\n";
                return undef;                
            } 
        }

        #################### GETTILE_PARAMS

        elsif ($parsed->{type} eq "GETTILE_PARAMS") {
            if (defined $value) {
                print STDERR "Value have to respect format GETTILE_PARAMS\n";
                return undef;                
            } 
        }

        #################### POINT

        elsif ($parsed->{type} eq "POINT") {
            if (defined $value && $value =~ m/([^,]+),(\S+)/) {
                $parsed->{x} = $1;
                $parsed->{y} = $2;

                if (! ROK4::Core::Utils::isNumber($parsed->{x}) || ! ROK4::Core::Utils::isNumber($parsed->{y})) {
                    print STDERR "Value have to respect format POINT:<FLOAT>,<FLOAT>\n";
                    return undef;
                }
            } else {
                print STDERR "Value have to respect format POINT:<FLOAT>,<FLOAT>\n";
                return undef;
            }
        }

        #################### PYRAMID_LIST

        elsif ($parsed->{type} eq "PYRAMID_LIST") {
            if (! defined $value) {
                print STDERR "Value have to respect format PYRAMID_LIST:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }

        #################### SLAB_INDICE

        elsif ($parsed->{type} eq "SLAB_INDICE") {
            if (defined $value && $value =~ m/([^,]+),(\S+)/) {
                $parsed->{col} = $1;
                $parsed->{row} = $2;

                if (! ROK4::Core::Utils::isPositiveInt($parsed->{col}) || ! ROK4::Core::Utils::isPositiveInt($parsed->{row})) {
                    print STDERR "Value have to respect format SLAB_INDICE:<COL INTEGER>,<ROW INTEGER>\n";
                    return undef;
                }
            } else {
                print STDERR "Value have to respect format SLAB_INDICE:<COL INTEGER>,<ROW INTEGER>\n";
                return undef;
            }
        }

        #################### SLAB_INDICES

        elsif ($parsed->{type} eq "SLAB_INDICES") {
            if (defined $value) {
                print STDERR "Value have to respect format SLAB_INDICES\n";
                return undef;                
            } 
        }

        #################### SLAB_INDICES_LIST

        elsif ($parsed->{type} eq "SLAB_INDICES_LIST") {
            if (! defined $value) {
                print STDERR "Value have to respect format SLAB_INDICES_LIST:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }

        #################### SLAB_INFO

        elsif ($parsed->{type} eq "SLAB_INFO") {
            if (defined $value) {
                print STDERR "Value have to respect format SLAB_INFO\n";
                return undef;                
            }
        }

        #################### SLAB_PATH

        elsif ($parsed->{type} eq "SLAB_PATH") {
            if (! defined $value) {
                print STDERR "Value have to respect format SLAB_PATH:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{slab_path} = $value;
        }

        #################### SLAB_PATHS

        elsif ($parsed->{type} eq "SLAB_PATHS") {
            if (defined $value) {
                print STDERR "Value have to respect format SLAB_PATHS\n";
                return undef;                
            }
        }

        #################### SLABS_COUNT

        elsif ($parsed->{type} eq "SLABS_COUNT") {
            if (defined $value) {
                print STDERR "Value have to respect format SLABS_COUNT\n";
                return undef;                
            }
        }

        #################### SQL_FILE

        elsif ($parsed->{type} eq "SQL_FILE") {

            if (! defined $value) {
                print STDERR "Value have to respect format SQL_FILE:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }

        #################### TILE_INDICE

        elsif ($parsed->{type} eq "TILE_INDICE") {
            if (defined $value && $value =~ m/([^,]+),(\S+)/) {
                $parsed->{col} = $1;
                $parsed->{row} = $2;

                if (! ROK4::Core::Utils::isPositiveInt($parsed->{col}) || ! ROK4::Core::Utils::isPositiveInt($parsed->{row})) {
                    print STDERR "Value have to respect format TILE_INDICE:<COL INTEGER>,<ROW INTEGER>\n";
                    return undef;
                }
            } else {
                print STDERR "Value have to respect format TILE_INDICE:<COL INTEGER>,<ROW INTEGER>\n";
                return undef;
            }
        }

        #################### TILE_INFO

        elsif ($parsed->{type} eq "TILE_INFO") {
            if (defined $value) {
                print STDERR "Value have to respect format TILE_INFO\n";
                return undef;                
            }            
        }

        #################### TFW_FILE

        elsif ($parsed->{type} eq "TFW_FILE") {

            if (! defined $value) {
                print STDERR "Value have to respect format TFW_FILE:<FILE PATH>\n";
                return undef;                
            }

            $parsed->{path} = $value;
        }
    }

    else {
        print STDERR "Cannot determine type\n";
        return undef;
    }

    return $parsed;
}

=begin nd
Function: init
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
        "version|v" => sub { print "$VERSION\n"; exit 0; },
        "help|h" => sub { print "$VERSION\n$help\n"; exit 0; },

        "tms=s" => \$options{tms},
        "slabsize=s" => \$options{slabsize},
        "storage=s" => \$options{storage},
        "above=s" => \$options{above},
        "level=s" => \$options{level},
        "ratio=s" => \$options{ratio},
        "from=s" => \$options{from},
        "to=s" => \$options{to},
        "buffer=s" => \$options{buffer},
        "progress" => \$options{progress}
    ) or do {
        print STDERR "Unappropriate usage\n";
        print STDERR "$VERSION\n$help\n";
        exit -1;
    };

    ############# tms
    if (! defined $options{"tms"} || $options{"tms"} eq "") {
        print STDERR "Option 'tms' not defined !\n";
        return FALSE;
    }

    my $tms = ROK4::Core::TileMatrixSet->new($options{"tms"}, TRUE);
    if (! defined $tms) {
        printf STDERR "Cannot create a TileMatrixSet object from the file %s\n", $options{"tms"};
        return FALSE;
    }
    $options{"tms"} = $tms;

    if (defined $options{"above"} && $options{"above"} ne "" && ! $tms->isQTree()) {
        print STDERR "Option 'above' only works for QTREE TMS\n";
        return FALSE;
    }

    ############# slabsize
    if (defined $options{"slabsize"} && $options{"slabsize"} ne "") {
        if ($options{"slabsize"} =~ m/^(\d+)x(\d+)$/) {
            $options{"slabsize"} = [$1, $2];
        } else {
            print STDERR "Option 'slabsize' have to respect format <integer>x<integer>\n";
            return FALSE;
        }
    } else {
        $options{"slabsize"} = undef;
    }

    ############# buffer
    if (defined $options{"buffer"} && $options{"buffer"} ne "") {
        if ($options{"buffer"} !~ m/^(\d+)$/) {
            print STDERR "Option 'buffer' have to respect format <integer>\n";
            return FALSE;
        }
    }

    ############# progress
    if ($options{"progress"}) {
        $options{"progress"} = {
            "bar" => undef,
            "complete" => undef,
            "next" => 0
        }
    }

    ############# storage

    my $storage = {
        type => "FILE",
        depth => 2
    };
    if (defined $options{"storage"} && $options{"storage"} ne "") {

        my @params = split(/:/, $options{"storage"});

        if (scalar(@params) == 1) {
            if ($params[0] ne "FILE" && $params[0] ne "CEPH" && $params[0] ne "S3" && $params[0] ne "SWIFT") {
                print STDERR "Option 'storage' have to respect format FILE[:<DEPTH>]|CEPH|S3|SWIFT\n";
                return FALSE;
            }
            if ($params[0] eq "CEPH" || $params[0] eq "S3" || $params[0] eq "SWIFT") {
                delete $storage->{depth};
                $storage->{type} = $params[0];
            }
        }
        elsif (scalar(@params) == 2) {
            if ($params[0] ne "FILE") {
                print STDERR "Option 'storage' have to respect format FILE[:<DEPTH>]|CEPH|S3|SWIFT\n";
                return FALSE;
            }
            if (! ROK4::Core::Utils::isStrictPositiveInt($params[1])) {
                print STDERR "Option 'storage' have to respect format FILE[:<DEPTH INTEGER>]|CEPH|S3|SWIFT\n";
                return FALSE;
            }
            $storage->{depth} = $params[1];
        }
        else {
            print STDERR "Option 'storage' have to respect format FILE[:<DEPTH>]|CEPH|S3|SWIFT\n";
            return FALSE;
        }
    }
    $options{"storage"} = $storage;

    ############# level
    if (defined $options{"level"} && $options{"level"} ne "") {
        if (! defined $options{tms}->getTileMatrix($options{"level"})) {
            printf STDERR "Level %s does not exist in the provided TMS", $options{"level"};
            return FALSE;
        } else {
            $options{"level"} = $options{tms}->getTileMatrix($options{"level"});
        }
    } else {
        $options{"level"} = undef;
    }

    ############# ratio
    if (defined $options{"ratio"} && $options{"ratio"} ne "") {
        if (! ROK4::Core::Utils::isStrictPositiveInt($options{"ratio"})) {
            print STDERR "Option 'ratio' have to be a not null positive integer\n";
            return FALSE;
        }
    } else {
        $options{"ratio"} = 1;
    }

    ############# from
    if (! defined $options{from} || $options{from} eq "") {
        print STDERR "Option 'from' not defined !\n";
        return FALSE;
    }

    $options{from} = parseFromTo($options{from});
    if (! defined $options{from}) {
        print STDERR "Cannot parse 'from' string\n";
        return FALSE;
    }

    if (exists $options{from}->{path} && ! -e $options{from}->{path}) {
        printf STDERR "Input file %s must exist\n", $options{from}->{path};
        return FALSE;
    }

    if ($options{from}->{type} eq "GEOM_FILE") {
        my $geom = ROK4::Core::ProxyGDAL::geometryFromFile($options{from}->{path});
        if (! defined $geom) {
            print STDERR "Cannot load geometry from file\n";
            return FALSE;
        }
        $options{from}->{geom} = $geom;
    }

    ############# to
    if (! defined $options{to} || $options{to} eq "") {
        print STDERR "Option 'to' not defined !\n";
        return FALSE;
    }

    $options{to} = parseFromTo($options{to});
    if (! defined $options{to}) {
        print STDERR "Cannot parse 'to' string\n";
        return FALSE;
    }

    if (exists $options{to}->{path} && -e $options{to}->{path}) {
        printf STDERR "Output file %s must not exist\n", $options{to}->{path};
        return FALSE;
    }

    return TRUE;
}

####################################################################################################
#                                 Group: Process methods                                           #
####################################################################################################

=begin nd
Variable: conversions

Hash reference containing all available conversions and mandatory options
=cut
my $conversions = {
                 BBOX => { GETTILE_PARAMS      => ["level","slabsize"] ,
                           SLAB_INDICES        => ["level","slabsize"] ,
                           SQL_FILE            => ["level","slabsize"] },
          BBOXES_LIST => { SLAB_INDICES        => ["level","slabsize"] },
            GEOM_FILE => { GETTILE_PARAMS      => ["level","slabsize"] ,
                           SLAB_INDICES        => ["level","slabsize"] ,
                           SLABS_COUNT         => ["level","slabsize"] ,
                           SQL_FILE            => ["level","slabsize"] },
                POINT => { SLAB_INFO           => ["slabsize"],
                           TILE_INFO           => [] },
         PYRAMID_LIST => { GEOM_FILE           => ["level","slabsize"] ,
                           GETTILE_PARAMS      => ["slabsize"] },
         SLAB_INDICE  => { TFW_FILE            => ["level","slabsize"], 
                           GEOM                => ["level","slabsize"] },
    SLAB_INDICES_LIST => { GETMAP_PARAMS       => ["level","slabsize"] ,
                           SLAB_PATHS          => ["level","slabsize"] },
            SLAB_PATH => { GEOM                => ["level","slabsize"] },
         TILE_INDICE  => { SLAB_INFO           => ["level","slabsize"] ,
                           GETMAP_PARAMS       => ["level"] }
};

=begin nd
Function: doIt
=cut
sub doIt {

    # Conversions autorisées ?
    if (! exists $conversions->{$options{from}->{type}}->{$options{to}->{type}}) {
        printf STDERR "%s -> %s is not handled\n", $options{from}->{type}, $options{to}->{type};
        return FALSE;
    }
    
    # Paramètres obligatoires présents ?
    my @mandatories = @{$conversions->{$options{from}->{type}}->{$options{to}->{type}}};
    foreach my $m (@mandatories) {
        if (! defined $options{$m}) {
            printf STDERR "Option '$m' is mandatory for conversion %s -> %s\n", $options{from}->{type}, $options{to}->{type};
            return FALSE;
        }
    }

    # ---------------------------------------------------------------------------------------------
    if ($options{from}->{type} eq "SLAB_INDICES_LIST" && $options{to}->{type} eq "GETMAP_PARAMS") {

        my $filein = $options{from}->{path};
        open(IN, "<$filein") or do {
            print STDERR "Cannot open $filein to read in it\n";
            return FALSE;
        };
                
        my $width = $options{"level"}->getTileWidth() * $options{"slabsize"}->[0];
        my $height = $options{"level"}->getTileHeight() * $options{"slabsize"}->[1];
        my $projection = $options{"tms"}->getSRS();
        my $inversion = $options{"tms"}->getInversion();
        my $memory = {};

        my $done = 0;
        if ($options{progress}) {
            $options{progress}->{complete} = `wc -l $filein | cut -d' ' -f1`;
            chomp($options{progress}->{complete});
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'GetMap writting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }

        while (my $line = <IN>) {
            chomp($line);
            $done++;

            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }

            if ($done % $options{ratio} != 0) {
                next;
            }

            my ($COL, $ROW) = split(/,/, $line);
            if (! exists $memory->{$COL}->{$ROW}) {
                $memory->{$COL}->{$ROW} = 1;
                my ($xMin,$yMin,$xMax,$yMax) = $options{"level"}->indicesToBbox($COL, $ROW, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);
                if ($inversion) {
                    print "WIDTH=$width&HEIGHT=$height&BBOX=$yMin,$xMin,$yMax,$xMax&CRS=$projection\n";
                } else {
                    print "WIDTH=$width&HEIGHT=$height&BBOX=$xMin,$yMin,$xMax,$yMax&CRS=$projection\n";
                }
            }
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
        
        close(IN);
    }


    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "SLAB_INDICES_LIST" && $options{to}->{type} eq "SLAB_PATHS") {

        if (! $options{tms}->isQTree()) {
            print STDERR "Only QTRee TMS are handled for conversion SLAB_INDICES_LIST -> SLAB_PATHS\n";
            return FALSE;
        }

        my $filein = $options{from}->{path};
        open(IN, "<$filein") or do {
            print STDERR "Cannot open $filein to read in it\n";
            return FALSE;
        };

        my $baseLevel = $options{level}->getID();
        my @aboveLevels;
        if (defined $options{above}) {
            @aboveLevels = $options{tms}->getTileMatrixByArray($baseLevel, $options{above});
        }
        
        my $memory = {};

        if ($options{progress}) {
            $options{progress}->{complete} = `wc -l $filein | cut -d' ' -f1`;
            chomp($options{progress}->{complete});
            $options{progress}->{bar} = Term::ProgressBar->new({name => "Slabs' paths writting...", count => $options{progress}->{complete}, fh => \*STDERR});
        }


        my $done = 0;

        while (my $line = <IN>) {
            chomp($line);
            $done++;

            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }

            my ($COL, $ROW) = split(/,/, $line);
            if (! exists $memory->{$baseLevel}->{$COL}->{$ROW}) {
                $memory->{$baseLevel}->{$COL}->{$ROW} = 1;
                if ($options{storage}->{type} eq "FILE") {
                    my $b36 = ROK4::Core::Base36::indicesToB36Path($COL, $ROW, $options{storage}->{depth} + 1);
                    print "$baseLevel/$b36.tif\n";
                } else {
                    print "${baseLevel}_${COL}_${ROW}\n";
                }
            }

            if (defined $options{above}) {
                for (my $i = 1; $i < scalar(@aboveLevels); $i++) {
                    my $levelID = $aboveLevels[$i]->getID();
                    $COL = int($COL / 2);
                    $ROW = int($ROW / 2);

                    if (! exists $memory->{$levelID}->{$COL}->{$ROW}) {
                        $memory->{$levelID}->{$COL}->{$ROW} = 1;
                        if ($options{storage}->{type} eq "FILE") {
                            my $b36 = ROK4::Core::Base36::indicesToB36Path($COL, $ROW, $options{storage}->{depth} + 1);
                            print "$levelID/$b36.tif\n";
                        } else {
                            print "${levelID}_${COL}_${ROW}\n";
                        }
                    }
                }
            }
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
        
        close(IN);
    }
    
    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "BBOXES_LIST" && $options{to}->{type} eq "SLAB_INDICES") {

        my $filein = $options{from}->{path};
        open(IN, "<$filein") or do {
            print STDERR "Cannot open $filein to read in it\n";
            return FALSE;
        };

        my $memory = {};

        if ($options{progress}) {
            $options{progress}->{complete} = `wc -l $filein | cut -d' ' -f1`;
            chomp($options{progress}->{complete});
            $options{progress}->{bar} = Term::ProgressBar->new({name => "Slabs' indices writting...", count => $options{progress}->{complete}, fh => \*STDERR});
        }

        my $done = 0;

        while (my $line = <IN>) {
            chomp($line);
            $done++;

            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }

            $line =~ s/\s//g;
            if (! ROK4::Core::Utils::isBbox($line)) {
                WARN("Line $. : '$line' is not a bbox");
                next;
            }
            my @bb = split(/,/,$line);

            my ($rowMin, $rowMax, $colMin, $colMax) = $options{"level"}->bboxToIndices(@bb, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);
            
            for (my $col = $colMin; $col <= $colMax; $col++) {
                for (my $row = $rowMin; $row <= $rowMax; $row++) {
                    if (! exists $memory->{$col}->{$row}) {
                        print "$col,$row\n";
                        $memory->{$col}->{$row} = 1;
                    }
                }
            }

        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
        
        close(IN);
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "PYRAMID_LIST" && $options{to}->{type} eq "GETTILE_PARAMS") {

        my $filein = $options{from}->{path};
        open(IN, "<$filein") or do {
            print STDERR "Cannot open $filein to read in it\n";
            return FALSE;
        };
        
        if ($options{progress}) {
            $options{progress}->{complete} = `wc -l $filein | cut -d' ' -f1`;
            chomp($options{progress}->{complete});
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'GetTile writting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }

        my $done = 0;
        my $slabs = 0;

        # On zappe les racines
        while (my $line = <IN>) {
            chomp($line);
            $done++;
            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }
            if ($line eq "#") {last;}
        }

        while (my $line = <IN>) {
            chomp($line);
            $done++;

            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }

            my ($level,$COL,$ROW);

            # Cas fichier
            if ($options{storage}->{type} eq "FILE") {
                # Une ligne du fichier c'est
                # Cas fichier : 0/DATA/15/AB/CD/EF.tif
                my @parts = split("/", $line);
                # La première partie est toujours l'index de la racine
                shift(@parts);
                # Dans le cas d'un stockage fichier, le premier élément du chemin est maintenant le type de donnée
                my $type = shift(@parts);
                if ($type ne "DATA") { next; }
                # et le suivant est le niveau
                $level = shift(@parts);
                if (defined $options{level} && $level ne $options{level}->getID()) { next; }

                my $path = join("/", @parts);
                $path =~ s/(\.tif|\.tiff|\.TIF|\.TIFF)//;
                ($COL,$ROW) = ROK4::Core::Base36::b36PathToIndices($path);
            }
            # Cas objet
            else {
                # Une ligne du fichier c'est
                # Cas objet : 0/DATA_15_15656_5423
                # On a un nom d'objet de la forme 0/TYPE_LEVEL_COL_ROW
                # TYPE vaut MASK ou DATA
                my @p = split("_",$line);
                my $type = $p[0];
                if ($type ne "DATA") { next; }
                $level = $p[-3];
                if (defined $options{level} && $level ne $options{level}->getID()) { next; }
                $COL = $p[-2];
                $ROW = $p[-1];
            }

            $slabs++;

            if ($slabs % $options{ratio} != 0) {
                next;
            }

            # On calcule l'indice d'une tuile dans la dalle
            my $col = $COL * $options{"slabsize"}->[0] + int(rand($options{"slabsize"}->[0]));
            my $row = $ROW * $options{"slabsize"}->[1] + int(rand($options{"slabsize"}->[1]));

            print "TILEMATRIX=$level&TILECOL=$col&TILEROW=$row\n";

        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
        
        close(IN);
    }
    
    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "SLAB_PATH" && $options{to}->{type} eq "GEOM") {

        my ($col,$row);

        # Cas fichier
        if ($options{storage}->{type} eq "FILE") {
            # Cas fichier : .../AB/CD/EF.tif
            my @parts = split("/", $options{from}->{slab_path});

            my @slab = ();
            for (my $i = 0; $i < $options{storage}->{depth} + 1; $i++) {
                my $p = pop(@parts);
                unshift(@slab, $p);
            }

            my $path = join("/", @slab);
            $path =~ s/(\.tif|\.tiff|\.TIF|\.TIFF)//;
            ($col,$row) = ROK4::Core::Base36::b36PathToIndices($path);
        }
        # Cas objet
        else {
            # Une ligne du fichier c'est
            # Cas objet : 0/PYRAMID_IMG_15_15656_5423
            # On a un nom d'objet de la forme BLA/BLA_BLA_DATATYPE_LEVEL_COL_ROW
            # DATATYPE vaut MASK ou IMG
            my @p = split("_", $options{from}->{slab_path});
            $col = $p[-2];
            $row = $p[-1];
        }

        my $geometry = $options{"level"}->indicesToGeom($col, $row, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);

        if (! defined $geometry) {
            print STDERR "Cannot calculate geometry from slab indices\n";
            return FALSE;
        }

        printf "%s\n", ROK4::Core::ProxyGDAL::getWkt($geometry);
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "PYRAMID_LIST" && $options{to}->{type} eq "GEOM_FILE") {

        my $filein = $options{from}->{path};
        open(IN, "<$filein") or do {
            print STDERR "Cannot open $filein to read in it\n";
            return FALSE;
        };

        if ($options{progress}) {
            $options{progress}->{complete} = `wc -l $filein | cut -d' ' -f1`;
            chomp($options{progress}->{complete});
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'Geometry writting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }
        
        my $done = 0;

        # On zappe les racines
        while (my $line = <IN>) {
            chomp($line);
            $done++;
            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }
            if ($line eq "#") {last;}
        }

        my $geometry = undef;
        while (my $line = <IN>) {
            chomp($line);
            $done++;
            if ($options{progress} && $done >= $options{progress}->{next}) {
                $options{progress}->{next} = $options{progress}->{bar}->update($done);
            }

            my ($col,$row);

            # Cas fichier
            if ($options{storage}->{type} eq "FILE") {
                # Une ligne du fichier c'est
                # Cas fichier : 0/DATA/15/AB/CD/EF.tif
                my @parts = split("/", $line);
                # La première partie est toujours l'index de la racine
                shift(@parts);
                # Dans le cas d'un stockage fichier, le premier élément du chemin est maintenant le type de donnée
                my $type = shift(@parts);
                if ($type ne "DATA") { next; }
                # et le suivant est le niveau
                my $level = shift(@parts);
                if ($level ne $options{level}->getID()) { next; }

                my $path = join("/", @parts);
                $path =~ s/(\.tif|\.tiff|\.TIF|\.TIFF)//;
                ($col,$row) = ROK4::Core::Base36::b36PathToIndices($path);
            }
            # Cas objet
            else {
                # Une ligne du fichier c'est
                # Cas objet : 0/DATA_15_15656_5423
                # On a un nom d'objet de la forme BLA/BLA_BLA/DATATYPE_LEVEL_COL_ROW
                # DATATYPE vaut MASK ou DATA
                my @p = split(/[_\/]/,$line);
                my $type = $p[-4];
                if ($type ne "DATA") { next; }
                my $level = $p[-3];
                if ($level ne $options{level}->getID()) { next; }
                $col = $p[-2];
                $row = $p[-1];
            }

            my $geom = $options{"level"}->indicesToGeom($col, $row, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);

            if (! defined $geometry) {
                $geometry = $geom;
            } else {
                $geometry = ROK4::Core::ProxyGDAL::getUnion($geometry,$geom);
            }
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }

        close(IN);

        if (! defined $geometry) {
            printf "WARN : No data slab in the pyramid's list for the level %s\n", $options{level}->getID();
            print "WARN : No file is written\n";
            return TRUE;
        }

        if (! ROK4::Core::ProxyGDAL::exportFile($geometry, $options{to}->{path})) {
            printf STDERR "Cannot write geometry into %s\n", $options{to}->{path};
            return FALSE;
        }
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "GEOM_FILE" && ($options{to}->{type} eq "SLAB_INDICES" || $options{to}->{type} eq "SQL_FILE" || $options{to}->{type} eq "GETTILE_PARAMS")) {

        my $bboxes = ROK4::Core::ProxyGDAL::getBboxes($options{from}->{geom});

        
        if (exists $options{to}->{path}) {
            my $fileout = $options{to}->{path};
            open(OUT, ">$fileout") or do {
                print STDERR "Cannot open $fileout to write in it\n";
                return FALSE;
            };
        }

        if ($options{to}->{type} eq "SQL_FILE") {
            print OUT "COPY slabs (level, col, row, geom) FROM stdin;\n";
        }

        my @extrema;
        my $complete = 0;

        for (my $i = 0; $i < scalar(@{$bboxes}); $i++) {
            my @ext = $options{"level"}->bboxToIndices(@{$bboxes->[$i]}, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);
            $complete += ( ($ext[1] - $ext[0] + 1)*($ext[3] - $ext[2] + 1) );
            push(@extrema, \@ext);
        }

        if ($options{progress}) {
            $options{progress}->{complete} = $complete;
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'Writting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }

        my $done = 0;
        my $memory = {};

        for (my $i = 0; $i < scalar(@{$bboxes}); $i++) {
        
            my ($rowMin, $rowMax, $colMin, $colMax) = @{$extrema[$i]};
            
            for (my $col = $colMin; $col <= $colMax; $col++) {
                for (my $row = $rowMin; $row <= $rowMax; $row++) {
                    $done++;
                    if (exists $memory->{$col}->{$row}) { next; }
                    $memory->{$col}->{$row} = 1;

                    my $OGRslab = $options{"level"}->indicesToGeom($col,$row,$options{"slabsize"}->[0], $options{"slabsize"}->[1]);

                    if (ROK4::Core::ProxyGDAL::isIntersected($OGRslab, $options{from}->{geom})) {
                        if ($options{to}->{type} eq "SQL_FILE") {
                            printf OUT "%s\t%s\t%s\t%s\n", 
                                $options{"level"}->getID(),
                                $col, $row,
                                ROK4::Core::ProxyGDAL::getWkb($OGRslab);
                        }
                        elsif ($options{to}->{type} eq "SLAB_INDICES") {
                            print "$col,$row\n";
                        }
                        elsif ($options{to}->{type} eq "GETTILE_PARAMS") {
                            my $c = $col * $options{"slabsize"}->[0] + int(rand($options{"slabsize"}->[0]));
                            my $r = $row * $options{"slabsize"}->[1] + int(rand($options{"slabsize"}->[1]));
                            printf "TILEMATRIX=%s&TILECOL=$c&TILEROW=$r\n", $options{"level"}->getID();
                        }
                    }

                    if ($options{progress} && $done >= $options{progress}->{next}) {
                        $options{progress}->{next} = $options{progress}->{bar}->update($done);
                    }

                }
            }
        }

        if ($options{to}->{type} eq "SQL_FILE") {
            print OUT "\\.\n\n";
        } 

        if (exists $options{to}->{path}) {
            close(OUT);
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "GEOM_FILE" && $options{to}->{type} eq "SLABS_COUNT") {

        my $bboxes = ROK4::Core::ProxyGDAL::getBboxes($options{from}->{geom});

        my @extrema;
        my $complete = 0;

        for (my $i = 0; $i < scalar(@{$bboxes}); $i++) {
            my @ext = $options{"level"}->bboxToIndices(@{$bboxes->[$i]}, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);
            $complete += ( ($ext[1] - $ext[0] + 1)*($ext[3] - $ext[2] + 1) );
            push(@extrema, \@ext);
        }

        if ($options{progress}) {
            $options{progress}->{complete} = $complete;
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'Counting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }

        my $done = 0;
        my $memory = {};
        my $count = 0;

        for (my $i = 0; $i < scalar(@{$bboxes}); $i++) {
        
            my ($rowMin, $rowMax, $colMin, $colMax) = @{$extrema[$i]};
            
            for (my $col = $colMin; $col <= $colMax; $col++) {
                for (my $row = $rowMin; $row <= $rowMax; $row++) {
                    $done++;

                    if (exists $memory->{$col}->{$row}) { next; }
                    $memory->{$col}->{$row} = 1;

                    my $OGRslab = $options{"level"}->indicesToGeom($col,$row,$options{"slabsize"}->[0], $options{"slabsize"}->[1]);

                    if (ROK4::Core::ProxyGDAL::isIntersected($OGRslab, $options{from}->{geom})) {
                        $count++;
                    }

                    if ($options{progress} && $done >= $options{progress}->{next}) {
                        $options{progress}->{next} = $options{progress}->{bar}->update($done);
                    }
                }
            }
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }

        printf "Level %s : $count slabs\n", $options{"level"}->getID();
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "BBOX" && ($options{to}->{type} eq "SLAB_INDICES" || $options{to}->{type} eq "SQL_FILE" || $options{to}->{type} eq "GETTILE_PARAMS")) {

        if (exists $options{to}->{path}) {
            my $fileout = $options{to}->{path};
            open(OUT, ">$fileout") or do {
                print STDERR "Cannot open $fileout to write in it\n";
                return FALSE;
            }; 
        }

        if ($options{to}->{type} eq "SQL_FILE") {
            print OUT "COPY slabs (level, col, row, geom) FROM stdin;\n";
        }

        my ($rowMin, $rowMax, $colMin, $colMax) = $options{"level"}->bboxToIndices(@{$options{from}->{bbox}}, $options{"slabsize"}->[0], $options{"slabsize"}->[1]);
        
        if ($options{progress}) {
            $options{progress}->{complete} = ($rowMax - $rowMin + 1)*($colMax - $colMin + 1);
            $options{progress}->{bar} = Term::ProgressBar->new({name => 'Slab indices list writting...', count => $options{progress}->{complete}, fh => \*STDERR});
        }

        my $done = 0;
        
        for (my $col = $colMin; $col <= $colMax; $col++) {
            for (my $row = $rowMin; $row <= $rowMax; $row++) {
                $done++;

                if ($options{to}->{type} eq "SQL_FILE") {
                    my $OGRslab = $options{"level"}->indicesToGeom($col,$row,$options{"slabsize"}->[0], $options{"slabsize"}->[1]);

                    printf OUT "%s\t%s\t%s\t%s\n", 
                        $options{"level"}->getID(),
                        $col, $row,
                        ROK4::Core::ProxyGDAL::getWkb($OGRslab);
                }
                elsif ($options{to}->{type} eq "SLAB_INDICES") {
                    print "$col,$row\n";
                }
                elsif ($options{to}->{type} eq "GETTILE_PARAMS") {
                    my $c = $col * $options{"slabsize"}->[0] + int(rand($options{"slabsize"}->[0]));
                    my $r = $row * $options{"slabsize"}->[1] + int(rand($options{"slabsize"}->[1]));
                    printf "TILEMATRIX=%s&TILECOL=$c&TILEROW=$r\n", $options{"level"}->getID();
                }

                if ($options{progress} && $done >= $options{progress}->{next}) {
                    $options{progress}->{next} = $options{progress}->{bar}->update($done);
                }

            }
        }

        if ($options{to}->{type} eq "SQL_FILE") {
            print OUT "\\.\n\n";
        } 

        if (exists $options{to}->{path}) {
            close(OUT);
        }

        if ($options{progress}) {
            $options{progress}->{bar}->update($options{progress}->{complete});
        }
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "SLAB_INDICE" && ($options{to}->{type} eq "TFW_FILE" || $options{to}->{type} eq "GEOM")) {

        my ($xMin,$yMin,$xMax,$yMax) = $options{"level"}->indicesToBbox(
            $options{from}->{col}, $options{from}->{row},
            $options{"slabsize"}->[0], $options{"slabsize"}->[1]
        );

        my $res = $options{"level"}->getResolution();

        if ($options{to}->{type} eq "TFW_FILE") {

            my $fileout = $options{to}->{path};
            open(OUT, ">$fileout") or do {
                print STDERR "Cannot open $fileout to write in it\n";
                return FALSE;
            };

            printf OUT "%s\n0\n0\n-%s\n", $res, $res;
            printf OUT "%s\n%s\n", $xMin + $res / 2, $yMax - $res / 2;

            close(OUT);
        } elsif ($options{to}->{type} eq "GEOM") {
            printf "%s\n", ROK4::Core::ProxyGDAL::getWkt(ROK4::Core::ProxyGDAL::geometryFromBbox($xMin,$yMin,$xMax,$yMax));
        }


    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "TILE_INDICE" && $options{to}->{type} eq "SLAB_INFO") {

        my $ID = $options{"level"}->getID();
        my $COL = int($options{from}->{col} / $options{"slabsize"}->[0]);
        my $ROW = int($options{from}->{row} / $options{"slabsize"}->[1]);

        my $storage = "";
        if ($options{storage}->{type} eq "FILE") {
            my $b36 = ROK4::Core::Base36::indicesToB36Path($COL, $ROW, $options{storage}->{depth} + 1);
            $storage = "$ID/$b36.tif";
        } else {
            $storage = "${ID}_${COL}_${ROW}";
        }

        print "Level $ID : slab indices ($COL,$ROW), storage $storage\n";
    }
    elsif ($options{from}->{type} eq "TILE_INDICE" && $options{to}->{type} eq "GETMAP_PARAMS") {

        my $projection = $options{"tms"}->getSRS();
        my $inversion = $options{"tms"}->getInversion();
        my $width = $options{"level"}->getTileWidth();
        my $height = $options{"level"}->getTileHeight();

        my ($xMin,$yMin,$xMax,$yMax) = $options{"level"}->indicesToBbox($options{from}->{col}, $options{from}->{row}, 1, 1);

        if ($options{buffer}) {
            my $incr = $options{"level"}->getResolution() * $options{buffer};
            $xMin -= $incr;
            $yMin -= $incr;
            $xMax += $incr;
            $yMax += $incr;
        }

        if ($inversion) {
            print "WIDTH=$width&HEIGHT=$height&BBOX=$yMin,$xMin,$yMax,$xMax&CRS=$projection\n";
        } else {
            print "WIDTH=$width&HEIGHT=$height&BBOX=$xMin,$yMin,$xMax,$yMax&CRS=$projection\n";
        }
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "POINT" && $options{to}->{type} eq "SLAB_INFO") {

        if (defined $options{"level"}) {
            my $ID = $options{"level"}->getID();
            my $COL = $options{"level"}->xToColumn($options{from}->{x}, $options{"slabsize"}->[0]);
            my $ROW = $options{"level"}->yToRow($options{from}->{y}, $options{"slabsize"}->[1]);

            my $storage = "";
            if ($options{storage}->{type} eq "FILE") {
                my $b36 = ROK4::Core::Base36::indicesToB36Path($COL, $ROW, $options{storage}->{depth} + 1);
                $storage = "$ID/$b36.tif";
            } else {
                $storage = "${ID}_${COL}_${ROW}";
            }

            print "Level $ID : slab indices ($COL,$ROW), storage $storage\n";
        } else {
            my @levels = $options{tms}->getTileMatrixByArray();

            foreach my $tm (@levels) {
                my $ID = $tm->getID();
                my $COL = $tm->xToColumn($options{from}->{x}, $options{"slabsize"}->[0]);
                my $ROW = $tm->yToRow($options{from}->{y}, $options{"slabsize"}->[1]);

                my $storage = "";
                if ($options{storage}->{type} eq "FILE") {
                    my $b36 = ROK4::Core::Base36::indicesToB36Path($COL, $ROW, $options{storage}->{depth} + 1);
                    $storage = "$ID/$b36.tif";
                } else {
                    $storage = "${ID}_${COL}_${ROW}";
                }

                print "Level $ID : slab indices ($COL,$ROW), storage $storage\n";
            }
        }
    }

    # ---------------------------------------------------------------------------------------------
    elsif ($options{from}->{type} eq "POINT" && $options{to}->{type} eq "TILE_INFO") {

        if (defined $options{"level"}) {
            my $ID = $options{"level"}->getID();
            my $COL = $options{"level"}->xToColumn($options{from}->{x});
            my $ROW = $options{"level"}->yToRow($options{from}->{y});
            
            print "Level $ID : tile indices ($COL,$ROW)\n";
        } else {

            my @levels = $options{tms}->getTileMatrixByArray();

            foreach my $tm (@levels) {
                my $ID = $tm->getID();
                my $COL = $tm->xToColumn($options{from}->{x});
                my $ROW = $tm->yToRow($options{from}->{y});
                
                print "Level $ID : tile indices ($COL,$ROW)\n";
            }
        }
    }

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
