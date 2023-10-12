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
    ##lz4c -9  1322.84 ms
    ##lz4c -1  1257.90 ms
    ##gzip     1138.87 ms
    cp -v ${BUILD}/kernel/arch/arm64/boot/Image.gz ${boot}/kernel.gz

    # dtb
    echo
   	info_msg "dtb(s)"
    cd ${BUILD}/kernel/arch/arm64/boot/dts/rockchip
    cp -v rk3399-nanopi4-rev00.dtb rk3399-nanopi4-rev01.dtb rk3399-nanopi4-rev04.dtb ${boot}/
    local dtbs=${boot}/rk3399-nanopi4-rev*.dtb
    ## friendlyarm disable rga by default, let's re-enable that.
    for dtb in ${dtbs}; do
        fdtput -t s ${dtb} /rga status "okay"
	done

    # initramfs
    echo
   	info_msg "initramfs"
    cd ${BUILD}/initramfs
    find . | cpio -oH newc | gzip > ${boot}/ramdisk.cpio.gz

    # resource.img
    echo
   	info_msg "resource.img"
    ${BUILD}/kernel/scripts/resource_tool \
        --pack \
        --image=${NANOPI4_DISTRO}/resource.img \
        --dtbname ${dtbs} ${HOME}/scripts/boot/logo.bmp ${HOME}/scripts/boot/logo_kernel.bmp

    local rkbin_tools=${BUILD}/rkbin/tools
    # FIT
    echo
   	info_msg "flattened device tree"
    cd ${HOME}/scripts/boot
    #address from @u-boo/include/configs/rk3399_common.h
    cp -v boot.script nanopi4.its ${boot}/
    ## binary path
    local bootimg=${boot}/image
    [ -d ${bootimg} ] && rm -rf ${bootimg}
    mkdir -p ${bootimg}
    ## mkimage
    echo
    ${rkbin_tools}/mkimage -C none -A arm64 -T script -d ${boot}/boot.script ${bootimg}/boot.scr
    echo
    ${rkbin_tools}/mkimage -f ${boot}/nanopi4.its ${bootimg}/nanopi4.itb
    echo
    ## ext2fs
    local boot_img=${NANOPI4_DISTRO}/boot.img
    [ -f ${boot_img} ] && rm -f ${boot_img}
    echo
   	info_msg "boot.img"
    genext2fs -b 4096 -d ${bootimg} ${boot_img}
    e2fsck -p -f ${boot_img}
    resize2fs -M ${boot_img}
}
