#!/bin/sh
#
#set -x

echo -e "\e[34m making rootfs package ... \e[0m"
sudo rm -rf ubuntu-rootfs
sudo qemu-debootstrap --arch=arm64 --variant=minbase --verbose --foreign bionic ubuntu-rootfs http://mirrors.aliyun.com/ubuntu-ports/

echo -e "\e[34m chroot && update rootfs ... \e[0m"
cat << EOF | sudo chroot ubuntu-rootfs /bin/bash

echo "
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse
" >> /etc/apt/sources.list

#export LANGUAGE=en_US.UTF-8
#export LC_ALL=en_US.UTF-8
#export LANG=en_US.UTF-8

#apt update
#apt upgrade -y

#apt install -y --no-install-recommends language-pack-en-base
#locale-gen en_US.UTF-8
#update-locale en_US.UTF-8

#apt install -y --no-install-recommends udev sudo ssh
#apt install -y --no-install-recommends wireless-tools wpasupplicant iputils-ping
#apt install -y --no-install-recommends ifupdown net-tools network-manager ethtool

#systemctl enable systemd-networkd
#systemctl enable systemd-resolved
#systemctl mask systemd-networkd-wait-online.service
#systemctl mask NetworkManager-wait-online.service

echo "oiramario" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "root:x:0:" > /etc/group
echo "root:x:0:0:root:/root:/bin/sh" > /etc/passwd

echo "\
auto eth0
iface eth0 inet dhcp" > /etc/network/interfaces.d/eth0

EOF

echo -e "\e[34m packing rootfs ... \e[0m"
sudo tar -cf ubuntu-rootfs.tar ubuntu-rootfs/

echo -e "\e[34m compressing rootfs ... \e[0m"
sudo xz -zef --threads=0 ubuntu-rootfs.tar

sudo rm -rf ubuntu-rootfs
echo -e "\e[32m done.\n \e[0m"
