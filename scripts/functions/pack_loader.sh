# Functions:
# pack_loader_image

source functions/common.sh


pack_loader_image()
{
    # clean
    rm -f ${NANOPI4_DISTRO}/rk3399_loader.bin
    rm -f ${NANOPI4_DISTRO}/idbloader.img
    rm -f ${NANOPI4_DISTRO}/uboot.img
    rm -f ${NANOPI4_DISTRO}/trust.img

    local rkbin_tools=${BUILD}/rkbin/tools
    cd ${BUILD}/rkbin

    # rk3399_loader.bin
    echo
   	info_msg "rk3399_loader.bin"
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
    cp -v rk3399_loader_*.bin ${NANOPI4_DISTRO}/rk3399_loader.bin
    cp -v idbloader.img uboot.img trust.img ${NANOPI4_DISTRO}/
}
