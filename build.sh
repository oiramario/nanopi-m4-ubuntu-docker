#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
[ ! -d $DISTRO ] && mkdir -p $DISTRO

DEVKIT=/opt/devkit
[ ! -d $DEVKIT ] && sudo mkdir -p $DEVKIT

docker build -t rk3399 .
