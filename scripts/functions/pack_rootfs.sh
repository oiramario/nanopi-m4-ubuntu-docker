# Functions:
# pack_rootfs_image

source functions/common.sh


pack_rootfs_image()
{
    # ubuntu rootfs
    echo
   	info_msg "ubuntu rootfs"
    local rootfs_dir=${BUILD}/rootfs
    if [ -d ${ROOTFS} ];then
        umount ${ROOTFS}/proc/sys/fs/binfmt_misc > /dev/null 2>&1
        umount ${ROOTFS}/proc > /dev/null 2>&1
        umount ${ROOTFS}/sys > /dev/null 2>&1
        umount ${ROOTFS}/dev/pts > /dev/null 2>&1
        umount ${ROOTFS}/dev > /dev/null 2>&1
    fi

    local rk_rootfs=${BUILD}/rk-rootfs-build

    # overlay
    echo
   	info_msg "overlay"
    cp -rf ${HOME}/scripts/overlays/rootfs/* ${ROOTFS}/

    # rockchip firmware
    echo
   	info_msg "copy rockchip firmwares"
    cp -rf ${rk_rootfs}/overlay-firmware/* ${ROOTFS}/

    # choose 64bits
    mv -f ${ROOTFS}/usr/bin/brcm_patchram_plus1_64 ${ROOTFS}/usr/bin/brcm_patchram_plus1
    mv -f ${ROOTFS}/usr/bin/rk_wifi_init_64 ${ROOTFS}/usr/bin/rk_wifi_init
    rm -f ${ROOTFS}/usr/bin/brcm_patchram_plus1_32 ${ROOTFS}/usr/bin/rk_wifi_init_32

    # bt, wifi, audio firmware
    echo
   	info_msg "copy bt/wifi/audio modules"
    mkdir -p ${ROOTFS}/system/lib/modules
    find ${BUILD}/kernel/drivers/net/wireless/rockchip_wlan -name "*.ko" | \
        xargs -n1 -i cp {} ${ROOTFS}/system/lib/modules/

    # mali
    # echo
   	# info_msg "mali"
    # cp -rf ${BUILD}/usr/* ${ROOTFS}/usr/
    # cp ${BUILD}/ogles-cube/gbm-drm-gles-cube ${ROOTFS}/usr/bin/
    #rm -rf ${ROOTFS}/usr/lib/pkgconfig


    # kernel modules
    # echo
   	# info_msg "copy kernel modules"
    # cp -rf ${BUILD}/kmodules/* ${ROOTFS}/

    # rockchip packages
    # echo
   	# info_msg "copy rockchip packages"
    # mkdir -p ${ROOTFS}/packages
    # cp -rf ${rk_rootfs}/packages/arm64/* ${ROOTFS}/packages/

    # rockchip overlay
    # echo
   	# info_msg "copy rockchip overlays"
    # cp -rf ${rk_rootfs}/overlay/* ${ROOTFS}/
    # chmod +x ${ROOTFS}/etc/rc.local

    # rockchip debug overlay
    # local rk_debug=${rk_rootfs}/overlay-debug
    # cp -rf $rk_debug/* ${ROOTFS}/
    # # glmark2
    # local dst_glmark2=${ROOTFS}/usr/local/share/glmark2
    # mkdir -p ${dst_glmark2}
    # local src_glmark2=${rk_debug}/usr/local/share/glmark2/aarch64
    # cp -rf ${src_glmark2}/share/* ${dst_glmark2}
    # cp ${src_glmark2}/bin/glmark2-es2 ${ROOTFS}/usr/local/bin/glmark2-es2

    # mount
    echo
   	info_msg "mount"
    mount -t proc /proc ${ROOTFS}/proc
    mount -t sysfs /sys ${ROOTFS}/sys
    mount -o bind /dev ${ROOTFS}/dev
    mount -o bind /dev/pts ${ROOTFS}/dev/pts
    mount binfmt_misc -t binfmt_misc ${ROOTFS}/proc/sys/fs/binfmt_misc
    update-binfmts --enable qemu-aarch64

    # building
    echo
   	info_msg "building rootfs"
    cp -v /usr/bin/qemu-aarch64-static ${ROOTFS}/usr/bin/
    cat << EOF | LC_ALL=C LANG=C chroot ${ROOTFS}/ /bin/bash
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

apt-get autoclean -y
apt-get autoremove -y
rm -rf var/lib/apt/lists/*
rm -rf var/cache/apt/archives/*.deb
rm -rf var/log/*
rm -rf tmp/* 
EOF
    rm ${ROOTFS}/usr/bin/qemu-aarch64-static
    sync
    umount ${ROOTFS}/proc/sys/fs/binfmt_misc
    umount ${ROOTFS}/proc
    umount ${ROOTFS}/sys
    umount ${ROOTFS}/dev/pts
    umount ${ROOTFS}/dev
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
    cp -rfp ${ROOTFS}/* ${rootfs_mnt}
    umount ${rootfs_mnt}
    e2fsck -p -f ${rootfs_img}
    resize2fs -M ${rootfs_img}
}
