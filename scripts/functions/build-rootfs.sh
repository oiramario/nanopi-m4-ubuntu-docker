#!/bin/bash
#
#set -x

# Functions:
# pack_initramfs_image
# pack_boot_image

## Functions
source functions/common-functions.sh


clean () {
    local rootfs_mnt=/tmp/rootfs-mnt
    if [ -d ${rootfs_mnt} ]; then
        umount ${rootfs_mnt} >/dev/null 2>&1
        rm -rf ${rootfs_mnt}
    fi

    local rootfs_dir=${BUILD}/rootfs
    if [ -d ${rootfs_dir} ]; then
        umount ${rootfs_dir}/proc >/dev/null 2>&1
        umount ${rootfs_dir}/sys >/dev/null 2>&1
        umount ${rootfs_dir}/dev/pts >/dev/null 2>&1
        umount ${rootfs_dir}/dev >/dev/null 2>&1
    fi

    local rootfs_img=${DISTRO}/rootfs.img
    rm -f ${rootfs_img}
}

finish () {
    clean
    exit 1
}
trap finish ERR


pack_rootfs_image()
{
    clean

    local rootfs_mnt=/tmp/rootfs-mnt
    local rootfs_dir=${BUILD}/rootfs

    # ubuntu bionic
    echo
   	info_msg "extract ubuntu-bionic packages"
    #qemu-debootstrap --arch=arm64 \
    #                 --variant=minbase \
    #                 --verbose \
    #                 --include=locales,ca-certificates \
    #                 --components=main,universe \
    #                 --foreign bionic ${rootfs_dir} http://mirrors.aliyun.com/ubuntu-ports/
    #tar xzf ${HOME}/packages/ubuntu-rootfs.tar.gz -C ${rootfs_dir}/
    cp -v /usr/bin/qemu-aarch64-static ${rootfs_dir}/usr/bin/

    # kernel modules
    echo
   	info_msg "copy kernel modules"
    cp -rf ${BUILD}/kmodules/* ${rootfs_dir}/

    # modules: bt, wifi, audio
    echo
   	info_msg "copy bt/wifi/audio modules"
    mkdir -p ${rootfs_dir}/system/lib/modules
    cd ${BUILD}/kernel-rockchip/drivers/net/wireless/rockchip_wlan
    find . -name "*.ko" | xargs -n1 -i cp {} ${rootfs_dir}/system/lib/modules

    local rk_rootfs=${BUILD}/rk-rootfs-build
    # rockchip packages
    #echo -e "\e[36m Copy packages \e[0m"
    #mkdir -p ${rootfs_dir}/packages
    #cp -rf ${rk_rootfs}/packages/arm64/* ${rootfs_dir}/packages/
    #echo -e "\e[32m Done \e[0m\n"

    # rockchip overlay
    echo
   	info_msg "copy rockchip overlays"
    cp -rf ${rk_rootfs}/overlay/* ${rootfs_dir}/
    chmod +x ${rootfs_dir}/etc/rc.local

    # rockchip firmware
    echo
   	info_msg "copy rockchip firmwares"
    cp -rf ${rk_rootfs}/overlay-firmware/* ${rootfs_dir}/
    mv -f ${rootfs_dir}/usr/bin/brcm_patchram_plus1_64 ${rootfs_dir}/usr/bin/brcm_patchram_plus1
    mv -f ${rootfs_dir}/usr/bin/rk_wifi_init_64 ${rootfs_dir}/usr/bin/rk_wifi_init
    rm -f ${rootfs_dir}/usr/bin/brcm_patchram_plus1_32  ${rootfs_dir}/usr/bin/rk_wifi_init_32
    # for wifi_chip save
    mkdir -p ${rootfs_dir}/data

    # config ubuntu
    echo
   	info_msg "config ubuntu"
    mount -t proc /proc ${rootfs_dir}/proc
    mount -t sysfs /sys ${rootfs_dir}/sys
    mount -o bind /dev ${rootfs_dir}/dev
    mount -o bind /dev/pts ${rootfs_dir}/dev/pts		

    # building ubuntu
    echo
   	info_msg "building rootfs"
    cat << EOF | LC_ALL=C LANG=C chroot ${rootfs_dir}/ /bin/bash
    set -x

    #------------------------------------------------------------------------
    echo -e "\033[36m apt update && upgrade && install packages.................... \033[0m"

    echo "nameserver 223.6.6.6" > /etc/resolv.conf

    echo '
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic main restricted universe multiverse
    deb http://mirrors.aliyun.com/ubuntu-ports/ bionic-updates main restricted universe multiverse
    ' > /etc/apt/sources.list

    export DEBIAN_FRONTEND=noninteractive 

    apt update

    export LC_ALL=C LANG=C
    apt install -y --no-install-recommends locales apt-utils
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_MESSAGES=en_US.UTF-8

    apt -y upgrade

    apt install -y --no-install-recommends init udev dbus rsyslog module-init-tools
    apt install -y --no-install-recommends iproute2 iputils-ping network-manager

    #mkdir -p /etc/bash_completion.d/
    #apt install -y --no-install-recommends ssh bash-completion htop
    # glmark2-es2

    #dpkg -i /packages/libdrm/*.deb
    #apt-get install -f -y

    #dpkg -i /packages/libmali/libmali-rk-midgard-t86x-r14p0_1.6-2_arm64.deb
    #apt-get install -f -y

    #dpkg -i /packages/libmali/libmali-rk-dev_1.6-2_arm64.deb
    #apt-get install -f -y

    #------------------------------------------------------------------------
    echo -e "\033[36m configuration.................... \033[0m"

    passwd root
    root
    root

    useradd -m -s /bin/bash flagon
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

    # TODO update modules.dep
    # depmod

    # TODO free rootfs size
    # resize2fs /dev/mmcblk1p6

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
    apt autoremove
    apt clean

EOF
    sync

    umount ${rootfs_dir}/proc
    umount ${rootfs_dir}/sys
    umount ${rootfs_dir}/dev/pts
    umount ${rootfs_dir}/dev
    sync

    # make rootfs.img
    echo
   	info_msg "make rootfs.img"
    dd if=/dev/zero of=${rootfs_img} bs=1M count=512
    mkfs.ext4 ${rootfs_img}
    mkdir -p ${rootfs_mnt}
    mount ${rootfs_img} ${rootfs_mnt}
    cp -rfp ${rootfs_dir}/* ${rootfs_mnt}
    umount ${rootfs_mnt}
    e2fsck -p -f ${rootfs_img}
    resize2fs -M ${rootfs_img}

    sync
}
