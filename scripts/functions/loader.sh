# Functions:
# pack_loader_image

source functions/common.sh


pack_loader_image()
{
    # clean
    rm -f ${DISTRO}/MiniLoaderAll.bin
    rm -f ${DISTRO}/idbloader.img
    rm -f ${DISTRO}/trust.img
    rm -f ${DISTRO}/uboot.img

    cd ${BUILD}/rkbin
    local path_fixup="--replace tools/rk_tools/ ./"

    # MiniLoaderAll.bin
    echo
   	info_msg "MiniLoaderAll.bin"
    tools/boot_merger ${path_fixup} RKBOOT/RK3399MINIALL.ini

    # idbloader.img
    echo
   	info_msg "idbloader.img"
    ${BUILD}/u-boot/tools/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img
    cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img

    # uboot.img
    echo
   	info_msg "uboot.img"
    tools/loaderimage --pack --uboot ../u-boot/u-boot.bin uboot.img 0x00200000

    # trust.img
    echo
   	info_msg "trust.img"
    tools/trust_merger ${path_fixup} RKTRUST/RK3399TRUST.ini

    cp -v idbloader.img uboot.img trust.img ${DISTRO}/
    cp -v rk3399_loader_*.bin ${DISTRO}/MiniLoaderAll.bin

    # qemu
    local qemu=${DISTRO}/qemu
    mkdir -p ${qemu}
    cp -v ../u-boot/u-boot.bin ${qemu}/
}
