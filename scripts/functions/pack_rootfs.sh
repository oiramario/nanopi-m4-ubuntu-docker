# Functions:
# pack_rootfs_image

source functions/common.sh


pack_rootfs_image()
{
    # ubuntu rootfs
    echo
   	info_msg "ubuntu rootfs"
    local rootfs_dir=${BUILD}/rootfs
    if [ -d ${rootfs_dir} ];then
        umount ${rootfs_dir}/proc/sys/fs/binfmt_misc > /dev/null 2>&1
        umount ${rootfs_dir}/proc > /dev/null 2>&1
        umount ${rootfs_dir}/sys > /dev/null 2>&1
        umount ${rootfs_dir}/dev/pts > /dev/null 2>&1
        umount ${rootfs_dir}/dev > /dev/null 2>&1

        rm -rf ${rootfs_dir}
    fi
    mkdir -p ${rootfs_dir}
    tar -xpf ${BUILD}/ubuntu-rootfs.tar.gz -C ${rootfs_dir}

    local rk_rootfs=${BUILD}/rk-rootfs-build

    # overlay
    echo
   	info_msg "overlay"
    cp -rf ./overlay/* ${rootfs_dir}/

    # rockchip firmware
    echo
   	info_msg "copy rockchip firmwares"
    cp -rf ${rk_rootfs}/overlay-firmware/etc ${rootfs_dir}/
    cp -rf ${rk_rootfs}/overlay-firmware/usr ${rootfs_dir}/
    cp -rf ${rk_rootfs}/overlay-firmware/lib ${rootfs_dir}/usr/

    # choose 64bits
    mv -f ${rootfs_dir}/usr/bin/brcm_patchram_plus1_64 ${rootfs_dir}/usr/bin/brcm_patchram_plus1
    mv -f ${rootfs_dir}/usr/bin/rk_wifi_init_64 ${rootfs_dir}/usr/bin/rk_wifi_init
    rm -f ${rootfs_dir}/usr/bin/brcm_patchram_plus1_32 ${rootfs_dir}/usr/bin/rk_wifi_init_32
    # for wifi_chip save
    mkdir -p ${rootfs_dir}/data

    # bt, wifi, audio firmware
    echo
   	info_msg "copy bt/wifi/audio modules"
    mkdir -p ${rootfs_dir}/system/lib/modules
    find ${BUILD}/kernel/drivers/net/wireless/rockchip_wlan -name "*.ko" | \
        xargs -n1 -i cp {} ${rootfs_dir}/system/lib/modules/

    # kernel modules
    # echo
   	# info_msg "copy kernel modules"
    # cp -rf ${BUILD}/kmodules/* ${rootfs_dir}/

    # rockchip packages
    # echo
   	# info_msg "copy rockchip packages"
    # mkdir -p ${rootfs_dir}/packages
    # cp -rf ${rk_rootfs}/packages/arm64/* ${rootfs_dir}/packages/

    # rockchip overlay
    # echo
   	# info_msg "copy rockchip overlays"
    # cp -rf ${rk_rootfs}/overlay/* ${rootfs_dir}/
    # chmod +x ${rootfs_dir}/etc/rc.local

    # rockchip debug overlay
    # local rk_debug=${rk_rootfs}/overlay-debug
    # cp -rf $rk_debug/* ${rootfs_dir}/
    # # glmark2
    # local dst_glmark2=${rootfs_dir}/usr/local/share/glmark2
    # mkdir -p ${dst_glmark2}
    # local src_glmark2=${rk_debug}/usr/local/share/glmark2/aarch64
    # cp -rf ${src_glmark2}/share/* ${dst_glmark2}
    # cp ${src_glmark2}/bin/glmark2-es2 ${rootfs_dir}/usr/local/bin/glmark2-es2

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

passwd root
root
root

useradd -m -s /bin/bash guest
passwd guest
111
111

export DEBIAN_FRONTEND=noninteractive 

apt-get update
#apt-get upgrade -y

# Install minimal packages:
apt-get install -y --no-install-recommends \
        init udev dbus rsyslog module-init-tools haveged \
        resolvconf iproute2 iputils-ping net-tools network-manager \
        ssh htop bash-completion

dpkg-reconfigure resolvconf

systemctl enable haveged
systemctl enable systemd-networkd
systemctl enable systemd-resolved

rm -rf /packages
apt-get autoclean -y
apt-get autoremove -y
rm -rf var/lib/apt/lists/*
rm -rf var/cache/apt/archives/*.deb
rm -rf var/log/*
rm -rf tmp/* 
EOF
    rm ${rootfs_dir}/usr/bin/qemu-aarch64-static
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
