#!/bin/sh
#
#set -x

DISTRO=$PWD/distro
if [ ! -e $DISTRO ]; then
    mkdir -p $DISTRO
fi

ROOTFS_DIR=$DISTRO/rootfs
ROOTFS_MNT=$DISTRO/rootfs-mnt
ROOTFS_IMG=$DISTRO/rootfs.img


# build docker
echo "\n\e[36m Building images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
echo "\n\e[36m Copy tarball from docker container \e[0m"
docker cp $id:/distro.tar $DISTRO/distro.tar
docker rm -fv $id
tar xf $DISTRO/distro.tar -C $DISTRO
rm $DISTRO/distro.tar
sync


finish () {
    sudo umount $ROOTFS_MNT >/dev/null 2>&1
    rm -rf $ROOTFS_MNT
    rm -rf $ROOTFS_DIR

    sudo cp -f distro/99-rk-rockusb.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger

    echo "\n\e[36m Done. \e[0m"
    ls $DISTRO -lh
}
trap finish EXIT


echo "\n\e[36m Build rootfs.img ... \e[0m"
dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=256
mkfs.ext4 -F -b 4096 -E stride=2,stripe-width=1024 -L rootfs $ROOTFS_IMG
mkdir -p $ROOTFS_MNT
sudo mount $ROOTFS_IMG $ROOTFS_MNT
sudo cp -R $ROOTFS_DIR/* $ROOTFS_MNT
sync
sudo umount $ROOTFS_MNT
e2fsck -p -f $ROOTFS_IMG
resize2fs -M $ROOTFS_IMG
