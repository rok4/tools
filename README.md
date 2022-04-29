# Outils de maintenance

Cette suite d'outil facilite la gestion des pyramides (suppression, statistiques), la création de descripteur de couche par défaut, ainsi qu'un outil de conversion basé sur les TMS.

- [Récupération du projet](#récupération-du-projet)
- [Dépendances à la compilation](#dépendances-à-la-compilation)
- [Installation](#installation)
- [Dépendances à l'exécution](#dépendances-à-lexécution)
- [Variables d'environnement utilisées dans les librairies ROK4::Core](#variables-denvironnement-utilisées-dans-les-librairies-rok4core)
- [Présentation des outils](#présentation-des-outils)
  - [CONVERT2JSON](#convert2json)
    - [Commande](#commande)
  - [SUP-PYR](#sup-pyr)
    - [Commande](#commande-1)
    - [Options](#options)
  - [CREATE-LAYER](#create-layer)
    - [Commandes](#commandes)
    - [Options](#options-1)
  - [PYROLYSE](#pyrolyse)
    - [Commande](#commande-2)
    - [Options](#options-2)
  - [TMS-TOOLBOX](#tms-toolbox)

## Récupération du projet

`git clone --recursive https://github.com/rok4/tools`

## Dépendances à la compilation

* Submodule GIT
    * `https://github.com/rok4/core-perl`
* Paquets debian
    * perl-base
    * libgdal-perl
    * libpq-dev
    * gdal-bin
    * libfile-find-rule-perl
    * libfile-copy-link-perl
    * libconfig-ini-perl
    * libdbi-perl
    * libdbd-pg-perl
    * libdevel-size-perl
    * libdigest-sha-perl
    * libfile-map-perl
    * libfindbin-libs-perl
    * libhttp-message-perl
    * liblwp-protocol-https-perl
    * libmath-bigint-perl
    * libterm-progressbar-perl
    * liblog-log4perl-perl
    * libjson-parse-perl
    * libjson-perl
    * libtest-simple-perl
    * libxml-libxml-perl
    * libamazon-s3-perl

## Installation

```shell
perl Makefile.PL INSTALL_BASE=/usr/local VERSION=0.0.1
make
make injectversion
make install
```

## Dépendances à l'exécution

* Dépôt GIT
    * `https://github.com/rok4/tilematrixsets`


## Variables d'environnement utilisées dans les librairies ROK4::Core

Leur définition est contrôlée à l'usage.

* `ROK4_TMS_DIRECTORY` pour y chercher les Tile Matrix Sets
* Pour le stockage CEPH
    - `ROK4_CEPH_CONFFILE`
    - `ROK4_CEPH_USERNAME`
    - `ROK4_CEPH_CLUSTERNAME`
* Pour le stockage S3
    - `ROK4_S3_URL`
    - `ROK4_S3_KEY`
    - `ROK4_S3_SECRETKEY`
* Pour le stockage SWIFT
    - `ROK4_SWIFT_AUTHURL`
    - `ROK4_SWIFT_USER`
    - `ROK4_SWIFT_PASSWD`
    - `ROK4_SWIFT_PUBLICURL`
    - Si authentification via Swift
        - `ROK4_SWIFT_ACCOUNT`
    - Si connection via keystone (présence de `ROK4_KEYSTONE_DOMAINID`)
        - `ROK4_KEYSTONE_DOMAINID`
        - `ROK4_KEYSTONE_PROJECTID`
* Pour configurer l'agent de requête (intéraction SWIFT et S3)
    - `ROK4_SSL_NO_VERIFY`
    - `HTTP_PROXY`
    - `HTTPS_PROXY`
    - `NO_PROXY`

## Présentation des outils

### CONVERT2JSON

Cet outil convertit un descripteur de pyramide de l'ancien format (XML) vers le nouveau (JSON).

#### Commande

`convert2json.pl <storage type>://<decriptor path>`

### SUP-PYR

Cet outil supprime une pyramide à partir de son descripteur. Pour une pyramide stockée en fichier, il suffit de supprimer le dossier des données. Dans le cas de stockage objet, le fichier liste est parcouru et les dalles sont supprimées une par une.

Stockages gérés : FICHIER, CEPH, S3, SWIFT

#### Commande

`sup-pyr.pl --pyramid=<storage type>://<decriptor path> [--full] [--stop]`

#### Options

* `--pyramid` Précise le chemin vers le descripteur de la pyramide à supprimer. Ce chemin est préfixé par le type de stockage du descripteur : `file://`, `s3://`, `ceph://` ou `swift://`
* `--full` Précise si on supprime également le fichier liste et le descripteur de la pyramide à la fin
* `--stop` Précise si on souhaite arrêter la suppression lorsqu'une erreur est rencontrée

### CREATE-LAYER

Cet outil génère un descripteur de couche pour ROK4SERVER à partir du descripteur de pyramide et du dossier des TileMatrixSets. La couche utilisera alors la pyramide en entrée dans sa globalité. Le descripteur de couche est écrit dans la sortie standard.

#### Commandes

* `create-layer.pl --pyramid=<storage type>://<decriptor path> [--title "Titre de la couche"] [--abstract "Résumé de la couche"]`

#### Options

* `--pyramid` Précise le chemin vers le descripteur de la pyramide que la couche doit utiliser. Ce chemin est préfixé par le type de stockage du descripteur : `file://`, `s3://`, `ceph://` ou `swift://`
* `--title <string>` Optionnel, titre de la couche
* `--abstract <string>` Optionnel, résumé de la couche

### PYROLYSE

Cet outil génère un fichier JSON contenant, pour les dalles et les tuiles, DATA ou MASK, la taille totale, le nombre, la taille moyenne minimale et maximale, au global et par niveau. Les tailles sont en octet et les mesures sont faites sur les vraies données (listées dans le fichier liste). Pour des données vecteur, on ne compte que les tuiles de taille non nulle.

Stockages gérés pour l'analyse des dalles : FICHIER, CEPH, S3, SWIFT
Stockages gérés pour l'analyse des tuiles : FICHIER, SWIFT

#### Commande

`pyrolyse.pl --pyramid=<storage type>://<decriptor path> --json=file [--slabs ALL|DATA|MASK] [--tiles ALL|DATA|MASK] [--perfs=file] [--follow-links] [--progress]`

#### Options

* `--pyramid` Précise le chemin vers le descripteur de la pyramide à analyser. Ce chemin est préfixé par le type de stockage du descripteur : `file://`, `s3://`, `ceph://` ou `swift://`
* `--json` Précise le fichier à écrire en sortie (ne doit pas exister)
* `--slabs` Précise si l'on veut analyser la taille des dalles
* `--tiles` Précise si l'on veut analyser la taille des tuiles
* `--perfs` Définit le fichier dans lequel écrire les temps de lecture des index des dalles (uniquement réalisé si on souhaite l'analyse des tailles des tuiles)
* `--follow-links` Précise si l'on souhaite traiter les cibles des liens comme des dalles de la pyramide (sinon on compte simplement le nombre de liens)
* `--progress` Active la barre de progression. Celle ci va sur la sortie des erreurs.

### TMS-TOOLBOX

Outil : `tms-toolbox.pl`

Ce outil permet de réaliser de nombreuses conversion entre indices de dalles, de tuiles, requêtes getTile ou getMap, liste de fichiers, géométrie WKT... grâce au TMS utilisé (ne nécessite pas de pyramide).

[Détails](./main/tms-toolbox.md)