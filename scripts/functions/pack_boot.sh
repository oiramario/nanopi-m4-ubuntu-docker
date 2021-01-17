# Functions:
# pack_boot_image
#set -x

source functions/common.sh


pack_boot_image()
{
    # clean
    local boot=/tmp/boot
    [ -d ${boot} ] && rm -rf ${boot}
    mkdir -p ${boot}

    cd ${BUILD}/kernel/arch/arm64/boot
    # kernel
    echo
   	info_msg "kernel"
    cp -v Image.gz ${boot}/kernel.gz

    # dtb
    echo
   	info_msg "dtb(s)"
    cp -v dts/rockchip/rk3399-nanopi-m4.dtb ${boot}/

    # initramfs
    echo
   	info_msg "initramfs"
    cd ${BUILD}/initramfs
    find . | cpio -oH newc | gzip > ${boot}/ramdisk.cpio.gz

    local rkbin_tools=${BUILD}/rkbin/tools

    # FIT
    echo
   	info_msg "flattened device tree"
    cd ${HOME}/scripts/boot
    cp -v boot.its boot.script nanopi-m4.its ${boot}/
    ## binary path
    local fit_path=${boot}/uImage
    [ -d ${fit_path} ] && rm -rf ${fit_path}
    mkdir -p ${fit_path}
    ## mkimage
    echo
    ${rkbin_tools}/mkimage -f ${boot}/boot.its ${fit_path}/boot.scr.uimg
    echo
    ${rkbin_tools}/mkimage -f ${boot}/nanopi-m4.its ${fit_path}/nanopi-m4.itb
    ## ext2fs
    local boot_img=${DISTRO}/boot.img
    [ -f ${boot_img} ] && rm -f ${boot_img}
    echo
   	info_msg "boot.img"
    genext2fs -b 16384 -d ${fit_path} ${boot_img}
    e2fsck -p -f ${boot_img}
    resize2fs -M ${boot_img}
}
