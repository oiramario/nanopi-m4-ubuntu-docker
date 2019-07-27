# Functions:
# pack_initramfs_image
# pack_boot_image

## Functions
source archives/functions/common-functions.sh


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
    local dptx_src=${BUILD}/rk-rootfs-build/overlay-firmware/lib/firmware/rockchip/dptx.bin
    local dptx_dst=${path}/lib/firmware/rockchip/dptx.bin
    mkdir -p ${dptx_dst}
    cp ${dptx_src} ${dptx_dst}

    # ramdisk.cpio.gz
    cd ${path}
    rm -f linuxrc
    cp -f ${HOME}/archives/boot/init ./
    find . | cpio -o -H newc | gzip > ${BOOT}/ramdisk.cpio.gz
}


pack_boot_image()
{
    # clean
    rm -f ${DISTRO}/boot.img

    BOOT=/tmp/boot
    if [ -d ${BOOT} ]; then
        rm -rf ${BOOT}
    fi
    mkdir -p ${BOOT}

    # initramfs
    echo
   	info_msg "ramdisk.cpio.gz"
    pack_initramfs_image

    cd ${BUILD}/kernel-rockchip/arch/arm64/boot
    # kernel
    echo
   	info_msg "kernel"
    cp Image.gz ${BOOT}/kernel.gz -v
    # dtb
    echo
   	info_msg "dtb(s)"
    cp dts/rockchip/rk3399-nanopi4-rev0*.dtb ${BOOT}/ -v

    # FIT
    local path=${BOOT}/uImage
    if [ -d ${path} ]; then
        rm -rf ${path}
    fi
    mkdir -p ${path}

    echo
   	info_msg "flattened device tree"
    cd ${HOME}/archives/boot
    cp autoscript.cmd fitImage.its ${BOOT}/

    cd ${BUILD}/u-boot/tools
    ./mkimage -C none -A arm64 -T script -d ${BOOT}/autoscript.cmd ${path}/boot.scr
    ./mkimage -f ${BOOT}/fitImage.its ${path}/fitImage.itb

    # make image
    echo
   	info_msg "boot.img"
    BOOT_IMG=${DISTRO}/boot.img
    genext2fs -b 16384 -d ${path} ${BOOT_IMG}
    e2fsck -p -f ${BOOT_IMG}
    resize2fs -M ${BOOT_IMG}
}
