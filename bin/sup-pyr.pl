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
File: sup-pyr.pl

Section: SUP-PYR tool

Synopsis:
    (start code)
    sup-pyr.pl --pyr=file [--full] [--stop]
    (end code)
=cut

################################################################################

use warnings;
use strict;

use POSIX qw(locale_h);

# Module
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Cwd;

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
my $VERSION = '@VERSION@';

=begin nd
Variable: options

Contains sup-pyr call options :

    version - To obtain the command's version
    help - To obtain the command's help
    usage - To obtain the command's usage
    
    pyr - To precise the pyramid's descriptor path
    full - To precise if we want to remove the pyramid's descriptor file and list file too
    stop - To precise if we have to stop when an error is occured
    
=cut
my %options =
(
    "version"    => 0,
    "help"       => 0,
    "usage"      => 0,

    # Mandatory
    "pyr"  => undef,
    # Optionnal
    "full"  => FALSE,
    "stop"  => FALSE
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
    printf("SUP-PYR : version [%s]\n",$VERSION);

    print STDOUT "BEGIN\n";

    # initialization
    ALWAYS("> Initialization");
    if (! main::init()) {
        print STDERR "ERROR INITIALIZATION !\n";
        exit 1;
    }

    # execution
    ALWAYS("> Execution");
    if (! main::doIt()) {
        print STDERR "ERROR EXECUTION !\n";
        exit 5;
    }

    print STDOUT "END\n";
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
            printf "See documentation here: https://github.com/rok4/rok4\n" ;
            exit 0;
        },
        "version|v" => sub { exit 0; },
        "usage" => sub {
            printf "See documentation here: https://github.com/rok4/rok4\n" ;
            exit 0;
        },
        
        "pyr=s" => \$options{pyr},
        "full" => \$options{full},
        "stop" => \$options{stop}
    ) or do {
        printf "Unappropriate usage\n";
        printf "See documentation here: https://github.com/rok4/rok4\n";
        exit -1;
    };
    
    # logger by default at runtime
    Log::Log4perl->easy_init({
        level => "INFO",
        layout => '%5p : %m (%M) %n'
    });
    
    ############# PYR
    if (! defined $options{pyr} || $options{pyr} eq "") {
        ERROR("Option 'pyr' not defined !");
        return FALSE;
    }
    
    ############# FULL

    if ($options{full} == 1) {
        INFO("We ask for a full removal");
        $options{full} = TRUE;
    }
    
    ############# STOP

    if ($options{stop} == 1) {
        INFO("We ask stopping to first error");
        $options{stop} = TRUE;
    }

    return TRUE;
}

####################################################################################################
#                                 Group: Process methods                                           #
####################################################################################################

=begin nd
Function: doIt

Use functions :
    - <ProxyStorage::remove>
=cut
sub doIt {

    my $objPyramid = ROK4::Core::ProxyPyramid::load($options{pyr});

    if (! defined $objPyramid) {
        ERROR("Cannot create the Pyramid object (neither raster nor vector)");
        return FALSE;
    }

    ALWAYS("Pyramid's type : ".ref ($objPyramid));

    my $storageType = $objPyramid->getStorageType();
    my $pyramidName = $objPyramid->getName();

    my $issue = FALSE;

    if ($storageType eq "FILE") {
        # Dans le cas fichier, on supprime un dossier tout simplement pour les données, pas besoin de fichier list
        INFO("Suppression de la pyramide FICHIER $pyramidName");


        my $dataDir = $objPyramid->getDataRoot();

        INFO("Suppression du dossier de données $dataDir");
        if (! ProxyStorage::remove("FILE", $dataDir)) {
            WARN("Impossible de supprimer le dossier $dataDir");
            $issue = TRUE;
            if ($options{stop}) {
                return FALSE;
            }
        }

        if ($options{full} && ! $issue) {

            # On supprime maintenant le descripteur et la liste
            INFO("Suppression du descripteur de pyramide ".$options{pyr});
            my $descriptorFile = $objPyramid->getDescriptorPath();
            if (! ProxyStorage::remove("FILE", $descriptorFile)) {
                WARN("Impossible de supprimer le descripteur de pyramide $descriptorFile");
                return FALSE;
            }

            my $listFile = $objPyramid->getListPath();
            if (-f $listFile) {
                WARN("Suppression de la liste $listFile");
                if (! ProxyStorage::remove("FILE", $listFile)) {
                    ERROR("Impossible de supprimer la liste $listFile");
                    return FALSE;
                }
            }
        }

        return TRUE;
    }

    # On est dans le cas d'un stockage objet : CEPH, S3 ou SWIFT
    INFO("Suppression de la pyramide $storageType $pyramidName");

    if (! $objPyramid->loadList()) {
        ERROR("Cannot cache content list of the pyramid to delete");
        return FALSE;
    }

    my $slabs = $objPyramid->getLevelsSlabs();
    my $dataRoot = $objPyramid->getDataRoot();
    while( my ($level, $levelSlabs) = each(%{$slabs}) ) {

        while( my ($key, $parts) = each(%{$slabs->{$level}->{DATA}}) ) {
            my $t = $parts->{name};

            # Le nom de pyramide est potentiellement celui d'une pyramide ancêtre qu'on a référencé par objet symbolique
            # Dans notre cas on veut bien sur supprimer l'objet symbolique et non la dalle dans la pyramide ancêtre
            # On va donc forcer la racine avec celle de la pyramide à supprimer, pas celle issue de la liste

            my $slab = "${dataRoot}/${t}";
            if (! ROK4::Core::ProxyStorage::remove($storageType, $slab)) {
                
                $issue = TRUE;
                if ($options{stop}) {
                    ERROR("Impossible de supprimer la dalle $storageType $slab");
                    return FALSE;
                } else {
                    WARN("Impossible de supprimer la dalle $storageType $slab");
                }
            }
        }

        while( my ($key, $parts) = each(%{$slabs->{$level}->{MASK}}) ) {
            my $t = $parts->{name};

            # Le nom de pyramide est potentiellement celui d'une pyramide ancêtre qu'on a référencé par objet symbolique
            # Dans notre cas on veut bien sur supprimer l'objet symbolique et non la dalle dans la pyramide ancêtre
            # On va donc forcer la racine avec celle de la pyramide à supprimer, pas celle issue de la liste

            my $slab = "${dataRoot}/${t}";
            if (! ROK4::Core::ProxyStorage::remove($storageType, $slab)) {
                
                $issue = TRUE;
                if ($options{stop}) {
                    ERROR("Impossible de supprimer la dalle $storageType $slab");
                    return FALSE;
                } else {
                    WARN("Impossible de supprimer la dalle $storageType $slab");
                }
            }
        }

    }

    if ($options{full} && ! $issue) {
        # On supprime maintenant le descripteur et la liste
        INFO("Suppression du descripteur de pyramide ".$options{pyr});
        my $descriptorPath = $objPyramid->getDescriptorPath();
        if (! ROK4::Core::ProxyStorage::remove($storageType, $descriptorPath)) {
            ERROR("Impossible de supprimer le descripteur de pyramide ".$options{pyr});
            return FALSE;
        }

        my $listPath = $objPyramid->getListPath();
        INFO("Suppression de la liste $listPath");
        if (! ROK4::Core::ProxyStorage::remove($storageType, $listPath)) {
            ERROR("Impossible de supprimer la liste $listPath");
            return FALSE;
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
