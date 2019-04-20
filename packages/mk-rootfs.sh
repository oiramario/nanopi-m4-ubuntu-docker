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

finish () {
    umount rootfs/proc >/dev/null 2>&1
    umount rootfs/sys >/dev/null 2>&1
    umount rootfs/dev/pts >/dev/null 2>&1
    umount rootfs/dev >/dev/null 2>&1
}
trap finish EXIT
trap finish ERR

echo -e "\e[34m making rootfs package ... \e[0m"
qemu-debootstrap --arch=arm64 --variant=minbase --verbose --foreign bionic rootfs http://mirrors.aliyun.com/ubuntu-ports/

#mkdir -p rootfs/packages
#cp -rf rk-rootfs-build/packages/arm64/* rootfs/packages/

# some configs
cp -rf rk-rootfs-build/overlay/* rootfs/
# firmware
mkdir -p rootfs/system/lib/modules/
cp -rf rk-rootfs-build/overlay-firmware/* rootfs/
mv -f rootfs/usr/bin/brcm_patchram_plus1_64 rootfs/usr/bin/brcm_patchram_plus1
mv -f rootfs/usr/bin/rk_wifi_init_64 rootfs/usr/bin/rk_wifi_init
rm -f rootfs/usr/bin/brcm_patchram_plus1_32  rootfs/usr/bin/rk_wifi_init_32 

if [ -d rootfs ]; then
    echo -e "\033[36m switch rootfs.................... \033[0m"

    mount -t proc /proc rootfs/proc
    mount -t sysfs /sys rootfs/sys
    mount -o bind /dev rootfs/dev
    mount -o bind /dev/pts rootfs/dev/pts		

    cat << EOF | chroot rootfs

#------------------------------------------------------------------------
echo -e "\033[36m configuration.................... \033[0m"

echo "nameserver 127.0.0.53" > /etc/resolv.conf

echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse" > /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list

#useradd -G sudo -m -s /bin/bash flagon
#passwd flagon
useradd -s '/bin/bash' -m -G adm,sudo yourusername

#echo "Set password for yourusername:"
#passwd yourusername
#echo "Set password for root:"
#passwd root

#dpkg-reconfigure resolvconf

echo oiramario > /etc/hostname
echo "127.0.0.1    localhost.localdomain localhost" > /etc/hosts
echo "127.0.0.1    oiramario" >> /etc/hosts

#------------------------------------------------------------------------
echo -e "\033[36m apt update.................... \033[0m"

apt update

export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends language-pack-en-base apt-utils
update-locale LANG=en_US.UTF-8

DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    sudo \
    ssh \
    udev \
    libusb-1.0-0 \
    ifupdown \
    net-tools \
    wireless-tools \
    wpasupplicant \
    network-manager \
    bash-completion

#------------------------------------------------------------------------
echo -e "\033[36m setup network.................... \033[0m"

#echo auto eth0 > etc/network/interfaces.d/eth0
#echo iface eth0 inet dhcp >> etc/network/interfaces.d/eth0
 
#echo auto wlan0 > etc/network/interfaces.d/wlan0
#echo iface wlan0 inet dhcp >> etc/network/interfaces.d/wlan0

#------------------------------------------------------------------------
echo -e "\033[36m custom script.................... \033[0m"

#systemctl enable systemd-networkd
#systemctl enable systemd-resolved
#systemctl enable rockchip.service
#systemctl mask systemd-networkd-wait-online.service
#systemctl mask NetworkManager-wait-online.service
#rm /lib/systemd/system/wpa_supplicant@.service

#------------------------------------------------------------------------
echo -e "\033[36m clean.................... \033[0m"

apt -y dist-upgrade

rm -rf /var/lib/apt/lists/*
apt -y autoremove
apt clean

EOF

    #echo -e "\e[34m packing rootfs ... \e[0m"
    #tar -cf ../distro/rootfs.tar rootfs/

    #echo -e "\e[34m compressing rootfs ... \e[0m"
    #xz -zef --threads=0 rootfs.tar

    echo -e "\e[32m done.\n \e[0m"
fi
