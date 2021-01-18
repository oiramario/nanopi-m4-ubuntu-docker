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

    # kernel
    echo
   	info_msg "kernel"
    lz4c -9 ${BUILD}/kernel/arch/arm64/boot/Image ${boot}/kernel.lz4

    # dtb
    echo
   	info_msg "dtb(s)"
    local dtbs=${BUILD}/kernel/arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev*.dtb
    cp -v ${dtbs} ${boot}/
    ## friendlyarm disable rga by default, let's re-enable that.
    for dtb in `ls ${boot}/rk3399-nanopi4-rev*.dtb`; do
        fdtput -t s ${dtb} /rga status "okay"
	done

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
    cp -v boot.its boot.script nanopi4.its ${boot}/
    ## binary path
    local bootimg=${boot}/image
    [ -d ${bootimg} ] && rm -rf ${bootimg}
    mkdir -p ${bootimg}
    ## mkimage
    echo
    ${rkbin_tools}/mkimage -f ${boot}/boot.its ${bootimg}/boot.scr.uimg
    echo
    ${rkbin_tools}/mkimage -f ${boot}/nanopi4.its ${bootimg}/nanopi4.itb
    ## logo
    echo
    info_msg "logo"
    lz4c -9 ${HOME}/scripts/boot/logo.bmp ${bootimg}/logo.lz4
    ## ext2fs
    local boot_img=${DISTRO}/boot.img
    [ -f ${boot_img} ] && rm -f ${boot_img}
    echo
   	info_msg "boot.img"
    genext2fs -b 16384 -d ${bootimg} ${boot_img}
    e2fsck -p -f ${boot_img}
    resize2fs -M ${boot_img}
}
