#!/bin/bash
#
#set -x

DISTRO=$PWD/distro
sudo rm -rf $DISTRO
mkdir -p $DISTRO

ROOTFS_DIR=$DISTRO/rootfs
ROOTFS_MNT=$DISTRO/rootfs-mnt
ROOTFS_IMG=$DISTRO/rootfs.img

unmount-rootfs() {
    sudo umount $ROOTFS_DIR/proc >/dev/null 2>&1
    sudo umount $ROOTFS_DIR/sys >/dev/null 2>&1
    sudo umount $ROOTFS_DIR/dev/pts >/dev/null 2>&1
    sudo umount $ROOTFS_DIR/dev >/dev/null 2>&1
}

finish () {
    unmount-rootfs

    sudo umount $ROOTFS_MNT >/dev/null 2>&1
    #rm -rf $ROOTFS_MNT
    #sudo rm -rf $ROOTFS_DIR
}
trap finish EXIT
trap finish ERR

# build docker
#------------------------------------------------------------------------
echo -e "\n\e[36m Building boot images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
docker cp $id:/distro.tar $DISTRO/distro.tar
docker rm -fv $id
tar xf $DISTRO/distro.tar -C $DISTRO
rm $DISTRO/distro.tar
sync

# build rootfs
#------------------------------------------------------------------------
echo -e "\n\e[36m Building rootfs \e[0m"
#sudo qemu-debootstrap --arch=arm64 --variant=minbase --verbose --include=locales,dbus --foreign bionic $ROOTFS_DIR http://mirrors.aliyun.com/ubuntu-ports/
sudo tar xzf packages/ubuntu-rootfs.tar.gz -C $ROOTFS_DIR/
sudo cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin

sudo mount -t proc /proc $ROOTFS_DIR/proc
sudo mount -t sysfs /sys $ROOTFS_DIR/sys
sudo mount -o bind /dev $ROOTFS_DIR/dev
sudo mount -o bind /dev/pts $ROOTFS_DIR/dev/pts		

cat << EOF | sudo chroot $ROOTFS_DIR/ /bin/bash

set -x

#------------------------------------------------------------------------
echo -e "\033[36m apt update && upgrade.................... \033[0m"

echo "nameserver 127.0.0.53" > /etc/resolv.conf

echo '
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse
' > /etc/apt/sources.list

export DEBIAN_FRONTEND=noninteractive 

apt update
apt -y upgrade

#------------------------------------------------------------------------
#echo -e "\033[36m apt install packages.................... \033[0m"

export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
apt install -y --no-install-recommends language-pack-en-base apt-utils
update-locale LANG=en_US.UTF-8

apt install -y --no-install-recommends init udev dbus rsyslog
apt install -y --no-install-recommends iproute2 iputils-ping network-manager
#apt install -y --no-install-recommends sudo ssh bash-completion htop

dpkg -i /packages/libdrm/*.deb
apt-get install -f -y

#------------------------------------------------------------------------
echo -e "\033[36m configuration.................... \033[0m"

passwd root
root
root

useradd -G sudo -m -s /bin/bash flagon
passwd flagon
111
111

echo "/dev/mmcblk1p6  /      ext4  noatime  0  0" >> /etc/fstab

echo oiramario > /etc/hostname
echo "127.0.0.1    localhost.localdomain localhost" > /etc/hosts
echo "127.0.0.1    oiramario" >> /etc/hosts

mkdir -pv /etc/systemd/network
echo '
# Use DHCP
[Match]
Name=eth0
[Network]
DHCP=yes
' > /etc/systemd/network/eth0.network

#------------------------------------------------------------------------
echo -e "\033[36m custom script.................... \033[0m"

systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable rockchip.service
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

#------------------------------------------------------------------------
echo -e "\033[36m clean.................... \033[0m"

rm -rf /var/lib/apt/lists/*
#rm -rf /packages

EOF
unmount-rootfs
sync

dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=512
mkfs.ext4 $ROOTFS_IMG
mkdir -p $ROOTFS_MNT
sudo mount $ROOTFS_IMG $ROOTFS_MNT
sudo cp -rfp $ROOTFS_DIR/* $ROOTFS_MNT
sudo umount $ROOTFS_MNT
e2fsck -p -f $ROOTFS_IMG
resize2fs -M $ROOTFS_IMG

echo -e "\n\e[36m Done. \e[0m"
ls $DISTRO -lh
