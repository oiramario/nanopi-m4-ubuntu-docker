# Functions:
# pack_initramfs_image
# pack_boot_image

## Functions
source functions/common.sh


pack_initramfs_image()
{
    local initramfs_path=/tmp/initramfs

    # clean
    [ -d ${initramfs_path} ] && rm -rf ${initramfs_path}
    mkdir -p ${initramfs_path}

    # busybox
    cp -rf ${BUILD}/initramfs/* ${initramfs_path}/

    # dptx.bin
    local dptx_src=${BUILD}/rk-rootfs-build/overlay-firmware/lib/firmware/rockchip/dptx.bin
    local dptx_dst=${initramfs_path}/lib/firmware/rockchip/dptx.bin
    mkdir -p ${dptx_dst}
    cp -v ${dptx_src} ${dptx_dst}

    # ramdisk.cpio.gz
    cd ${initramfs_path}
    rm -f linuxrc
    cp -vf ${HOME}/scripts/boot/init ./
    find . | cpio -ovH newc | gzip > ${boot}/ramdisk.cpio.gz
}


pack_boot_image()
{
    # clean
    local boot_img=${DISTRO}/boot.img
    [ -f ${boot_img} ] && rm -f ${boot_img}

    local boot=/tmp/boot
    [ -d ${boot} ] && rm -rf ${boot}
    mkdir -p ${boot}

    # initramfs
    echo
   	info_msg "ramdisk.cpio.gz"
    pack_initramfs_image

    cd ${BUILD}/kernel-rockchip/arch/arm64/boot
    # kernel
    echo
   	info_msg "kernel"
    cp -v Image.gz ${boot}/kernel.gz
    # dtb
    echo
   	info_msg "dtb(s)"
    cp -v dts/rockchip/rk3399-nanopi4-rev0*.dtb ${boot}/

    # FIT
    local fit_path=${boot}/uImage
    [ -d ${fit_path} ] && rm -rf ${fit_path}
    mkdir -p ${fit_path}

    echo
   	info_msg "flattened device tree"
    cd ${HOME}/scripts/boot
    cp -v autoscript.cmd fitImage.its ${boot}/

    cd ${BUILD}/u-boot/tools
    ./mkimage -C none -A arm64 -T script -d ${boot}/autoscript.cmd ${fit_path}/boot.scr
    ./mkimage -f ${boot}/fitImage.its ${fit_path}/fitImage.itb

    # make image
    echo
   	info_msg "boot.img"
    genext2fs -b 16384 -d ${fit_path} ${boot_img} -v
    e2fsck -p -f ${boot_img}
    resize2fs -M ${boot_img}
}
