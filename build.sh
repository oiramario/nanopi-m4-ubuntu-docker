#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
[ ! -d $DISTRO ] && mkdir -p $DISTRO

DEVKIT=/opt/devkit
[ ! -d $DEVKIT ] && sudo mkdir -p $DEVKIT

docker build -t rk3399 . --build-arg Dummy=0 $1 $2 $3
