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
    ## nanopi4-rev* dtb
    cp -v dts/rockchip/rk3399-nanopi4-rev00.dtb dts/rockchip/rk3399-nanopi4-rev01.dtb dts/rockchip/rk3399-nanopi4-rev04.dtb ${boot}/
    ## friendlyarm disable rga by default, let's re-enable that.
    for dtb in `ls ${boot}/rk3399-nanopi4-rev0*.dtb`; do
        # use fdtput to avoid patch rk3399-nanopi4-common.dtsi in kernel
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
    cp -v boot.fit boot.scr fitImage.its ${boot}/
    ## binary path
    local fit_path=${boot}/uImage
    [ -d ${fit_path} ] && rm -rf ${fit_path}
    mkdir -p ${fit_path}
    ## mkimage
    echo
    ${rkbin_tools}/mkimage -f ${boot}/boot.fit ${fit_path}/boot.scr.uimg
    echo
    ${rkbin_tools}/mkimage -f ${boot}/fitImage.its ${fit_path}/fitImage.itb
    ## ext2fs
    local boot_img=${DISTRO}/boot.img
    [ -f ${boot_img} ] && rm -f ${boot_img}
    echo
   	info_msg "boot.img"
    genext2fs -b 16384 -d ${fit_path} ${boot_img}
    e2fsck -p -f ${boot_img}
    resize2fs -M ${boot_img}

    # resource
    echo
   	info_msg "resource"
    cd ${boot}/
    cp ${HOME}/scripts/boot/logo.bmp ./
    cp ${HOME}/scripts/boot/logo_kernel.bmp ./
    ${rkbin_tools}/resource_tool --pack --verbose --image=${DISTRO}/resource.img logo.bmp logo_kernel.bmp rk3399-nanopi4-rev01.dtb
}
