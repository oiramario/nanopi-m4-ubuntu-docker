#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
[ ! -d $DISTRO ] && mkdir -p $DISTRO

docker run -it \
    -v $(pwd)/distro:/root/distro \
    -v $(pwd)/scripts:/root/scripts:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --privileged \
    rk3399:latest \
    /bin/bash #./make.sh boot
