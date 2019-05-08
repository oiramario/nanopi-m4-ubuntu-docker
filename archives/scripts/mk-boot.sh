#!/bin/bash
#
#set -x

rm -f ${DISTRO}/MiniLoaderAll.bin
rm -f ${DISTRO}/idbloader.img
rm -f ${DISTRO}/trust.img
rm -f ${DISTRO}/uboot.img
rm -f ${DISTRO}/boot.img

BOOT=/tmp/boot
if [ -d ${BOOT} ]; then
    rm -rf ${BOOT}
fi
mkdir -p ${BOOT}


pack_loader_image()
{
    cd ${BUILD}/rkbin
    cp -f idbloader.img uboot.img trust.img ${DISTRO}/
    cp -f rk3399_loader_*.bin ${DISTRO}/MiniLoaderAll.bin
}


pack_initramfs_image()
{
    local path=/tmp/initramfs

    if [ -d ${path} ]; then
        rm -rf ${path}
    fi
    mkdir -p ${path}

    # busybox
    cp -rf ${BUILD}/initramfs/* ${path}/

    # dptx.bin
    cd /tmp
    local dptx_src=rk-rootfs-build/overlay-firmware/lib/firmware/rockchip/dptx.bin
    tar xzf ${HOME}/packages/rk-rootfs-build.tar.gz ${dptx}
    local dptx_dst=${path}/lib/firmware/rockchip/dptx.bin
    mkdir -p ${dptx_dst}
    cp /tmp/${dptx_src} ${dptx_dst}

    # ramdisk.cpio.gz
    cd ${path}
    rm -f linuxrc
    cp -f ${HOME}/archives/boot/init ./
    find . | cpio -o -H newc | gzip > ${BOOT}/ramdisk.cpio.gz
}


pack_boot_image()
{
    pack_initramfs_image

    cd ${BUILD}/kernel-rockchip/arch/arm64/boot
    # kernel
    cp Image.gz ${BOOT}/kernel.gz
    # dtb
    cp dts/rockchip/rk3399-nanopi4-rev0*.dtb ${BOOT}/

    # FIT
    local path=${BOOT}/uImage
    if [ -d ${path} ]; then
        rm -rf ${path}
    fi
    mkdir -p ${path}

    cd ${HOME}/archives/boot
    cp autoscript.cmd fitImage.its ${BOOT}/

    cd ${BUILD}/u-boot/tools
    ./mkimage -C none -A arm64 -T script -d ${BOOT}/autoscript.cmd ${path}/boot.scr
    ./mkimage -f ${BOOT}/fitImage.its ${path}/fitImage.itb

    # make image
    BOOT_IMG=${DISTRO}/boot.img
    genext2fs -b 16384 -d ${path} ${BOOT_IMG}
    e2fsck -p -f ${BOOT_IMG}
    resize2fs -M ${BOOT_IMG}
}


finish()
{
    ls ${DISTRO} -lh
    echo -e "\n\e[36m Done. \e[0m"
}


pack_loader_image
pack_boot_image
finish
