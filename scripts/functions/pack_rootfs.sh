# Functions:
# pack_rootfs_image

source functions/common.sh


pack_rootfs_image()
{
    local rk_rootfs=${BUILD}/rk-rootfs-build
    local rootfs_dir=${BUILD}/rootfs

    # rockchip packages
    echo
   	info_msg "copy rockchip packages"
    mkdir -p ${rootfs_dir}/packages
    cp -rf ${rk_rootfs}/packages/arm64/* ${rootfs_dir}/packages/

    # rockchip overlay
    echo
   	info_msg "copy rockchip overlays"
    cp -rf ${rk_rootfs}/overlay/* ${rootfs_dir}/
    chmod +x ${rootfs_dir}/etc/rc.local 

    # rockchip firmware
    echo
   	info_msg "copy rockchip firmwares"
    cp -rf ${rk_rootfs}/overlay-firmware/* ${rootfs_dir}/
    # some configs
    cd ${rootfs_dir}/usr/bin
    mv -f brcm_patchram_plus1_64 brcm_patchram_plus1
    mv -f rk_wifi_init_64 rk_wifi_init
    rm -f brcm_patchram_plus1_32 rk_wifi_init_32
    # for wifi_chip save
    mkdir -p ${rootfs_dir}/data

    # bt, wifi, audio firmware
    echo
   	info_msg "copy bt/wifi/audio modules"
    mkdir -p ${rootfs_dir}/system/lib/modules
    cd ${BUILD}/kernel-rockchip/drivers/net/wireless/rockchip_wlan
    find . -name "*.ko" | xargs -n1 -i cp {} ${rootfs_dir}/system/lib/modules

    # kernel modules
    echo
   	info_msg "copy kernel modules"
    cp -rf ${BUILD}/kmodules/* ${rootfs_dir}/

    # debug
    local rk_debug=${rk_rootfs}/overlay-debug
    cp -rf $rk_debug/* ${rootfs_dir}/
    # glmark2
    local dst_glmark2=${rootfs_dir}/usr/local/share/glmark2
    mkdir -p ${dst_glmark2}
    local src_glmark2=${rk_debug}/usr/local/share/glmark2/aarch64
    cp -rf ${src_glmark2}/share/* ${dst_glmark2}
    cp ${src_glmark2}/bin/glmark2-es2 ${rootfs_dir}/usr/local/bin/glmark2-es2

    # mount
    echo
   	info_msg "mount"
    mount -t proc /proc ${rootfs_dir}/proc
    mount -t sysfs /sys ${rootfs_dir}/sys
    mount -o bind /dev ${rootfs_dir}/dev
    mount -o bind /dev/pts ${rootfs_dir}/dev/pts
    mount binfmt_misc -t binfmt_misc ${rootfs_dir}/proc/sys/fs/binfmt_misc
    update-binfmts --enable qemu-aarch64

    # building
    echo
   	info_msg "building rootfs"
    cp -v /usr/bin/qemu-aarch64-static ${rootfs_dir}/usr/bin/
    cat << EOF | LC_ALL=C LANG=C chroot ${rootfs_dir}/ /bin/bash
    set -x

    uname -a

    #------------------------------------------------------------------------
    echo -e "\033[36m apt update && upgrade && install packages.................... \033[0m"

    echo "nameserver 8.8.8.8" > /etc/resolv.conf

    echo '
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic main restricted universe multiverse
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-updates main restricted universe multiverse
    ' > /etc/apt/sources.list

    export DEBIAN_FRONTEND=noninteractive 

    apt-get update

    # basic config
    export LC_ALL=C LANG=C
    apt-get install -y --no-install-recommends locales apt-utils
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_MESSAGES=en_US.UTF-8

    # rockchip libdrm
    dpkg -i /packages/libdrm/*.deb
    apt-get install -f -y

    # rockchip libmali
    apt-get install -y --no-install-recommends libdrm2 libx11-6 libx11-xcb1 libxcb-dri2-0 libxcb1
    dpkg -i /packages/libmali/*.deb
    apt-get install -f -y

    # advance config
    mkdir -p /etc/bash_completion.d/
    apt-get install -y --no-install-recommends \
            init udev dbus rsyslog module-init-tools \
            iproute2 iputils-ping network-manager \
            ssh bash-completion htop

    # upgrade
    apt-get upgrade -y

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
    #rm /lib/systemd/system/wpa_supplicant@.service

    #------------------------------------------------------------------------
    echo -e "\033[36m clean.................... \033[0m"

    rm -rf /packages
    apt-get autoremove -y
    apt-get clean -y
    rm -rf /var/lib/apt/lists/*
 
EOF
    sync
    umount ${rootfs_dir}/proc/sys/fs/binfmt_misc
    umount ${rootfs_dir}/proc
    umount ${rootfs_dir}/sys
    umount ${rootfs_dir}/dev/pts
    umount ${rootfs_dir}/dev
    sync


    # make rootfs.img
    echo
   	info_msg "make rootfs.img"
    local rootfs_mnt=/tmp/rootfs-mnt
    [ -d ${rootfs_mnt} ] && rm -rf ${rootfs_mnt}
    local rootfs_img=${DISTRO}/rootfs.img
    [ -f ${rootfs_img} ] && rm -f ${rootfs_img}

    dd if=/dev/zero of=${rootfs_img} bs=1M count=1024
    mkfs.ext4 ${rootfs_img}
    mkdir -p ${rootfs_mnt}
    mount ${rootfs_img} ${rootfs_mnt}
    cp -rfp ${rootfs_dir}/* ${rootfs_mnt}
    umount ${rootfs_mnt}
    e2fsck -p -f ${rootfs_img}
    resize2fs -M ${rootfs_img}
}
