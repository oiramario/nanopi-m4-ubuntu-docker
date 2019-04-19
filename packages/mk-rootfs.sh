#!/bin/bash
#
#set -x

if [ ! `id -u` = 0 ] ; then
    echo -e "\e[5m script must running with root. \e[0m"
    exit
fi

if [ -d rootfs ]; then
    rm -rf rootfs
fi

if [ -f rootfs.* ]; then
    rm -f rootfs.*
fi

echo -e "\e[34m making rootfs package ... \e[0m"
qemu-debootstrap --arch=arm64 --variant=minbase --verbose --foreign bionic rootfs http://mirrors.aliyun.com/ubuntu-ports/

if [ -d rootfs ]; then
    echo -e "\e[34m switch rootfs ... \e[0m"
    cat << EOF | chroot rootfs

    echo -e "
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse
    " >> /etc/apt/sources.list

    USER=flagon
    HOST=oiramario

    useradd -G sudo -m -s /bin/bash $USER
    passwd $USER

    echo $HOST > /etc/hostname
    echo "127.0.0.1    localhost.localdomain localhost" > /etc/hosts
    echo "127.0.0.1    $HOST" >> /etc/hosts
    
    echo "auto eth0" > /etc/network/interfaces.d/eth0
    echo "iface eth0 inet dhcp" >> /etc/network/interfaces.d/eth0
    echo "nameserver 127.0.1.1" > /etc/resolv.conf

    DEBIAN_FRONTEND=noninteractive apt update && \
                                   apt -y dist-upgrade && \
                                   apt install -y --no-install-recommends 
                                        sudo \
                                        ssh \
                                        udev \
                                        libusb-1.0-0 \
                                        ifupdown \
                                        net-tools \
                                        wireless-tools \
                                        wpasupplicant \
                                        network-manager \
                                        rsyslog \
                                        bash-completion

    #systemctl enable systemd-networkd
    #systemctl enable systemd-resolved
    #systemctl mask systemd-networkd-wait-online.service
    #systemctl mask NetworkManager-wait-online.service

    apt -y autoremove
    apt clean
EOF

    echo -e "\e[34m packing rootfs ... \e[0m"
    tar -cf rootfs.tar rootfs/

    echo -e "\e[34m compressing rootfs ... \e[0m"
    xz -zef --threads=0 rootfs.tar

    echo -e "\e[32m done.\n \e[0m"
fi
