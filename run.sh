#!/bin/bash
#
#set -x

NANOPI4_DISTRO=$(pwd)/distro
[ ! -d $NANOPI4_DISTRO ] && mkdir -p $NANOPI4_DISTRO

NANOPI4_DEVKIT=/opt/devkit
[ ! -d $NANOPI4_DEVKIT ] && sudo mkdir -p $NANOPI4_DEVKIT

docker run -it \
    -v $NANOPI4_DISTRO:/root/distro \
    -v $NANOPI4_DEVKIT:/root/devkit \
    -v $(pwd)/scripts:/root/scripts:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --privileged \
    rk3399:latest \
    /bin/bash #./make.sh rootfs
