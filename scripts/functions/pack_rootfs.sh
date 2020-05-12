# Functions:
# pack_rootfs_image

source functions/common.sh


pack_rootfs_image()
{
    # ubuntu rootfs
    echo
   	info_msg "ubuntu rootfs"
    local rootfs=/tmp/rootfs
    if [ -d ${rootfs} ];then
        umount ${rootfs}/proc/sys/fs/binfmt_misc > /dev/null 2>&1
        umount ${rootfs}/proc > /dev/null 2>&1
        umount ${rootfs}/sys > /dev/null 2>&1
        umount ${rootfs}/dev/pts > /dev/null 2>&1
        umount ${rootfs}/dev > /dev/null 2>&1
        rm -rf ${rootfs}
    fi
    mkdir -p ${rootfs}
    cp -rfp ${ROOTFS}/* ${rootfs}/

    # overlay
    echo
   	info_msg "overlay"
    cp -rf ${HOME}/scripts/overlays/rootfs/* ${rootfs}/

    # rockchip firmware
    local rk_rootfs=${BUILD}/rk-rootfs-build
    echo
   	info_msg "copy rockchip firmwares"
    cp -rf ${rk_rootfs}/overlay-firmware/* ${rootfs}/

    # choose 64bits
    mv -f ${rootfs}/usr/bin/brcm_patchram_plus1_64 ${rootfs}/usr/bin/brcm_patchram_plus1
    mv -f ${rootfs}/usr/bin/rk_wifi_init_64 ${rootfs}/usr/bin/rk_wifi_init
    rm -f ${rootfs}/usr/bin/brcm_patchram_plus1_32 ${rootfs}/usr/bin/rk_wifi_init_32

    # bt, wifi, audio firmware
    echo
   	info_msg "copy bt/wifi/audio modules"
    mkdir -p ${rootfs}/system/lib/modules
    find ${BUILD}/kernel/drivers/net/wireless/rockchip_wlan -name "*.ko" | \
        xargs -n1 -i cp {} ${rootfs}/system/lib/modules/

    # kernel modules
    # echo
   	# info_msg "copy kernel modules"
    # cp -rf ${BUILD}/kmodules/* ${rootfs}/

    # rockchip packages
    # echo
   	# info_msg "copy rockchip packages"
    # mkdir -p ${rootfs}/packages
    # cp -rf ${rk_rootfs}/packages/arm64/* ${rootfs}/packages/

    # rockchip overlay
    # echo
   	# info_msg "copy rockchip overlays"
    # cp -rf ${rk_rootfs}/overlay/* ${rootfs}/
    # chmod +x ${rootfs}/etc/rc.local

    # mount
    echo
   	info_msg "mount"
    mount -t proc /proc ${rootfs}/proc
    mount -t sysfs /sys ${rootfs}/sys
    mount -o bind /dev ${rootfs}/dev
    mount -o bind /dev/pts ${rootfs}/dev/pts
    mount binfmt_misc -t binfmt_misc ${rootfs}/proc/sys/fs/binfmt_misc
    update-binfmts --enable qemu-aarch64

    # building
    echo
   	info_msg "building rootfs"
    cp -v /usr/bin/qemu-aarch64-static ${rootfs}/usr/bin/
    cat << EOF | LC_ALL=C LANG=C chroot ${rootfs}/ /bin/bash
set -x

uname -a

passwd root
root
root

useradd -m -s /bin/bash flagon
passwd flagon
111
111
adduser flagon sudo

export DEBIAN_FRONTEND=noninteractive 

apt-get update
#apt-get upgrade -y

apt-get install -y --no-install-recommends \
        init udev dbus rsyslog module-init-tools \
        network-manager iputils-ping \
        bluetooth bluez bluez-tools rfkill \
        sudo ssh htop file \
        bash-completion

systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

apt-get autoclean -y
apt-get autoremove -y
rm -rf var/lib/apt/lists/*
rm -rf var/cache/apt/archives/*.deb
rm -rf var/log/*
rm -rf tmp/*
EOF
    rm ${rootfs}/usr/bin/qemu-aarch64-static
    sync
    umount ${rootfs}/proc/sys/fs/binfmt_misc
    umount ${rootfs}/proc
    umount ${rootfs}/sys
    umount ${rootfs}/dev/pts
    umount ${rootfs}/dev
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
    cp -rfp ${rootfs}/* ${rootfs_mnt}
    umount ${rootfs_mnt}
    e2fsck -p -f ${rootfs_img}
    resize2fs -M ${rootfs_img}
}
