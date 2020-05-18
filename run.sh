#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
[ ! -d $DISTRO ] && mkdir -p $DISTRO

DEVKIT=/opt/devkit
[ ! -d $DEVKIT ] && sudo mkdir -p $DEVKIT

docker run -it \
    -v $DISTRO:/root/distro \
    -v $DEVKIT:/root/devkit \
    -v $(pwd)/scripts:/root/scripts:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --privileged \
    rk3399:latest \
    /bin/bash #./make.sh rootfs
