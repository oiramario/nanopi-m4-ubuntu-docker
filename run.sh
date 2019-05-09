#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
if [ ! -d $DISTRO ]; then
    mkdir -p $DISTRO
fi

docker run -it \
    -v $(pwd)/distro:/root/distro \
    -v $(pwd)/archives:/root/archives:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --privileged \
    rk3399
