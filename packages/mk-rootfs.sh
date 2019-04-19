#!/bin/bash
#
#set -x

if [ ! `id -u` = 0 ] ; then
    echo -e "\e[5m script must running with root. \e[0m"
    exit
fi

if [ -d ubuntu-rootfs ]; then
    rm -rf ubuntu-rootfs
fi

if [ -f ubuntu-rootfs.* ]; then
    rm -f ubuntu-rootfs.*
fi

echo -e "\e[34m making rootfs package ... \e[0m"
qemu-debootstrap --arch=arm64 --variant=minbase --verbose --foreign bionic ubuntu-rootfs http://mirrors.aliyun.com/ubuntu-ports/

if [ -d ubuntu-rootfs ]; then
    echo -e "\e[34m chroot && update rootfs ... \e[0m"
    cat << EOF | chroot ubuntu-rootfs /bin/bash

    echo -e "
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse
    " >> /etc/apt/sources.list

    export LANGUAGE=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8

    apt update
    apt upgrade -y

    #apt install -y --no-install-recommends language-pack-en-base
    #locale-gen en_US.UTF-8
    #update-locale en_US.UTF-8

    #apt install -y --no-install-recommends udev ssh
    #apt install -y --no-install-recommends wireless-tools wpasupplicant iputils-ping
    #apt install -y --no-install-recommends ifupdown net-tools network-manager ethtool

    #systemctl enable systemd-networkd
    #systemctl enable systemd-resolved
    #systemctl mask systemd-networkd-wait-online.service
    #systemctl mask NetworkManager-wait-online.service

    echo -e "oiramario" > /etc/hostname
    echo -e "127.0.0.1 localhost" > /etc/hosts
    echo -e "root:x:0:" > /etc/group
    echo -e "root:x:0:0:root:/root:/bin/sh" > /etc/passwd

    #echo -e "\
    #auto eth0
    #iface eth0 inet dhcp" > /etc/network/interfaces.d/eth0

EOF

    echo -e "\e[34m packing rootfs ... \e[0m"
    tar -cf ubuntu-rootfs.tar ubuntu-rootfs/

    echo -e "\e[34m compressing rootfs ... \e[0m"
    xz -zef --threads=0 ubuntu-rootfs.tar

    echo -e "\e[32m done.\n \e[0m"
fi
