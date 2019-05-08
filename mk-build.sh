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
    -v $(pwd)/packages/rk-rootfs-build.tar.gz:/root/packages/rk-rootfs-build.tar.gz:ro \
    -v $(pwd)/packages/ubuntu-rootfs.tar.gz:/root/packages/ubuntu-rootfs.tar.gz:ro \
    -v /etc/localtime:/etc/localtime:ro \
    --privileged \
    rk3399
