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
#qemu-debootstrap --arch=arm64 --variant=minbase --verbose --foreign bionic rootfs http://mirrors.aliyun.com/ubuntu-ports/
sudo tar xzf packages/ubuntu-rootfs.tar.gz -C $ROOTFS_DIR/
sudo cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin

sudo mount -t proc /proc $ROOTFS_DIR/proc
sudo mount -t sysfs /sys $ROOTFS_DIR/sys
sudo mount -o bind /dev $ROOTFS_DIR/dev
sudo mount -o bind /dev/pts $ROOTFS_DIR/dev/pts		

cat << EOF | sudo chroot $ROOTFS_DIR/ /bin/bash

set -x
#------------------------------------------------------------------------
echo -e "\033[36m configuration.................... \033[0m"

echo "nameserver 127.0.0.53" > /etc/resolv.conf

echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse" > /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list

passwd root
root
root

useradd -G sudo -m -s /bin/bash flagon
passwd flagon
51211314
51211314

#echo "/dev/mmcblk1p6  /      ext4  defaults,noatime,errors=remount-ro  0  1" >> /etc/fstab

echo oiramario > /etc/hostname
echo "127.0.0.1    localhost.localdomain localhost" > /etc/hosts
echo "127.0.0.1    oiramario" >> /etc/hosts

#------------------------------------------------------------------------
echo -e "\033[36m apt update && upgrade.................... \033[0m"
apt update

#DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends locales apt-utils
#export LANGUAGE=en_US.UTF-8
#export LANG=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
#locale-gen en_US.UTF-8
#dpkg-reconfigure locales

#apt -y upgrade

echo -e "\033[36m apt install base.................... \033[0m"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
     init \
     udev
#    systemd \
#    rsyslog \
#    init \
#    udev

#echo -e "\033[36m apt install network.................... \033[0m"
#DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
#    net-tools 
#    wireless-tools \
#    wpasupplicant \
#    network-manager

#------------------------------------------------------------------------
#echo -e "\033[36m setup network.................... \033[0m"

#echo auto eth0 > etc/network/interfaces.d/eth0
#echo iface eth0 inet dhcp >> etc/network/interfaces.d/eth0
 
#echo auto wlan0 > etc/network/interfaces.d/wlan0
#echo iface wlan0 inet dhcp >> etc/network/interfaces.d/wlan0

#------------------------------------------------------------------------
#echo -e "\033[36m custom script.................... \033[0m"

#systemctl enable systemd-networkd
#systemctl enable systemd-resolved
#systemctl enable rockchip.service
#systemctl mask systemd-networkd-wait-online.service
#systemctl mask NetworkManager-wait-online.service
#rm /lib/systemd/system/wpa_supplicant@.service

#systemctl mask systemd-backlight@backlight:acpi_video0

#------------------------------------------------------------------------
#echo -e "\033[36m clean.................... \033[0m"

rm -rf /var/lib/apt/lists/*
apt -y autoremove
apt clean

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
