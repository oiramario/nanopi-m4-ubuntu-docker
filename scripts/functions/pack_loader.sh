# Functions:
# pack_loader_image

source functions/common.sh


pack_loader_image()
{
    # clean
    rm -f ${DISTRO}/MiniLoaderAll.bin
    rm -f ${DISTRO}/idbloader.img
    rm -f ${DISTRO}/uboot.img
    rm -f ${DISTRO}/trust.img

    local rkbin_tools=${BUILD}/rkbin/tools
    cd ${BUILD}/rkbin

    # MiniLoaderAll.bin
    echo
   	info_msg "MiniLoaderAll.bin"
    ${rkbin_tools}/boot_merger pack RKBOOT/RK3399MINIALL.ini

    # idbloader.img
    echo
   	info_msg "idbloader.img"
    ${rkbin_tools}/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img
    cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img

    # uboot.img
    echo
   	info_msg "uboot.img"
    ${rkbin_tools}/loaderimage --pack --uboot ../u-boot/u-boot.bin uboot.img 0x00200000

    # trust.img
    echo
   	info_msg "trust.img"
    ${rkbin_tools}/trust_merger --pack RKTRUST/RK3399TRUST.ini

    # distro
    echo
    cp -v rk3399_loader_*.bin ${DISTRO}/MiniLoaderAll.bin
    cp -v idbloader.img uboot.img trust.img ${DISTRO}/
}
