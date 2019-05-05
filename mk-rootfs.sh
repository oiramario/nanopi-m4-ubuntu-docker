#!/bin/bash
#
#set -x

if [ ! `id -u` = 0 ] ; then
    echo -e "\e[5m script must running with root. \e[0m"
    exit
fi


DISTRO=$PWD/distro
mkdir -p $DISTRO

ROOTFS_IMG=$DISTRO/rootfs.img
rm -f $ROOTFS_IMG

ROOTFS_MNT=/tmp/rk3399-rootfs-mnt
if [ -d $ROOTFS_MNT ]; then
    umount $ROOTFS_MNT >/dev/null 2>&1
    rm -rf $ROOTFS_MNT
fi

ROOTFS_DIR=/tmp/rk3399-rootfs
if [ -d $ROOTFS_DIR ]; then
    umount $ROOTFS_DIR/proc >/dev/null 2>&1
    umount $ROOTFS_DIR/sys >/dev/null 2>&1
    umount $ROOTFS_DIR/dev/pts >/dev/null 2>&1
    umount $ROOTFS_DIR/dev >/dev/null 2>&1

    rm -rf $ROOTFS_DIR
fi

finish () {
    umount $ROOTFS_DIR/proc >/dev/null 2>&1
    umount $ROOTFS_DIR/sys >/dev/null 2>&1
    umount $ROOTFS_DIR/dev/pts >/dev/null 2>&1
    umount $ROOTFS_DIR/dev >/dev/null 2>&1
    umount $ROOTFS_MNT >/dev/null 2>&1

    rm -rf $ROOTFS_MNT
    rm -rf $ROOTFS_DIR

    exit 1
}
trap finish ERR

test () {
    echo "exit..."
}
trap test EXIT


# build rootfs
#------------------------------------------------------------------------
echo -e "\n\e[36m Extract image \e[0m"

rm -rf $ROOTFS_DIR
mkdir -p $ROOTFS_DIR

#qemu-debootstrap --arch=arm64 --variant=minbase --verbose --include=locales,dbus --foreign bionic $ROOTFS_DIR http://mirrors.aliyun.com/ubuntu-ports/
tar xzf packages/ubuntu-rootfs.tar.gz -C $ROOTFS_DIR/
cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin

echo -e "\n\e[36m Copy overlay to rootfs \e[0m"
tar xzf packages/rk-rootfs-build.tar.gz -C /tmp/
mkdir -p $ROOTFS_DIR/packages

RK_ROOTFS=/tmp/rk-rootfs-build
cp -rf $RK_ROOTFS/packages/arm64/* $ROOTFS_DIR/packages/
# some configs
cp -rf $RK_ROOTFS/overlay/* $ROOTFS_DIR/
# firmware
cp -rf $RK_ROOTFS/overlay-firmware/* $ROOTFS_DIR/
mv -f $ROOTFS_DIR/usr/bin/brcm_patchram_plus1_64 $ROOTFS_DIR/usr/bin/brcm_patchram_plus1
mv -f $ROOTFS_DIR/usr/bin/rk_wifi_init_64 $ROOTFS_DIR/usr/bin/rk_wifi_init
rm -f $ROOTFS_DIR/usr/bin/brcm_patchram_plus1_32  $ROOTFS_DIR/usr/bin/rk_wifi_init_32

mount -t proc /proc $ROOTFS_DIR/proc
mount -t sysfs /sys $ROOTFS_DIR/sys
mount -o bind /dev $ROOTFS_DIR/dev
mount -o bind /dev/pts $ROOTFS_DIR/dev/pts		

cat << EOF | chroot $ROOTFS_DIR/ /bin/bash

set -x

#------------------------------------------------------------------------
echo -e "\033[36m apt update && upgrade && install packages.................... \033[0m"

echo "nameserver 223.5.5.5" > /etc/resolv.conf
echo "nameserver 223.6.6.6" >> /etc/resolv.conf

echo '
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
' > /etc/apt/sources.list

export DEBIAN_FRONTEND=noninteractive 

apt update

export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
apt install -y --no-install-recommends language-pack-en-base apt-utils
update-locale LANG=en_US.UTF-8

apt -y upgrade

apt install -y --no-install-recommends init udev dbus rsyslog
apt install -y --no-install-recommends iproute2 iputils-ping network-manager
#apt install -y --no-install-recommends ssh bash-completion htop

#dpkg -i /packages/libdrm/*.deb
#apt-get install -f -y

#------------------------------------------------------------------------
echo -e "\033[36m configuration.................... \033[0m"

passwd root
root
root

useradd -G -m -s /bin/bash flagon
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

EOF

umount $ROOTFS_DIR/proc
umount $ROOTFS_DIR/sys
umount $ROOTFS_DIR/dev/pts
umount $ROOTFS_DIR/dev
sync

dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=512
mkfs.ext4 $ROOTFS_IMG
mkdir -p $ROOTFS_MNT
mount $ROOTFS_IMG $ROOTFS_MNT
cp -rfp $ROOTFS_DIR/* $ROOTFS_MNT
umount $ROOTFS_MNT
e2fsck -p -f $ROOTFS_IMG
resize2fs -M $ROOTFS_IMG

sync
rm -rf $ROOTFS_MNT
rm -rf $ROOTFS_DIR

echo -e "\n\e[36m Done. \e[0m"
ls $DISTRO -lh
