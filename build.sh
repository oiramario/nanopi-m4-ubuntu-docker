#!/bin/bash
#
#set -x

NANOPI4_DISTRO=$(pwd)/distro
[ ! -d $NANOPI4_DISTRO ] && mkdir -p $NANOPI4_DISTRO

NANOPI4_DEVKIT=/opt/devkit
[ ! -d $NANOPI4_DEVKIT ] && sudo mkdir -p $NANOPI4_DEVKIT

docker build -t nanopim4 . 
