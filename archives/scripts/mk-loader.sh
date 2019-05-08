#!/bin/bash
#
#set -x

pack_loader_image()
{
    # clean
    rm -f ${DISTRO}/MiniLoaderAll.bin
    rm -f ${DISTRO}/idbloader.img
    rm -f ${DISTRO}/trust.img
    rm -f ${DISTRO}/uboot.img

    cd ${BUILD}/rkbin
    local path_fixup="--replace tools/rk_tools/ ./"

    # boot loader
    tools/boot_merger ${path_fixup} RKBOOT/RK3399MINIALL.ini

    # idbloader.img
    ${BUILD}/u-boot/tools/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img
    cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img

    # uboot.img
    tools/loaderimage --pack --uboot ../u-boot/u-boot.bin uboot.img 0x00200000

    # trust.img
    tools/trust_merger ${path_fixup} RKTRUST/RK3399TRUST.ini

    cp -f idbloader.img uboot.img trust.img ${DISTRO}/
    cp -f rk3399_loader_*.bin ${DISTRO}/MiniLoaderAll.bin
}


finish()
{
    ls ${DISTRO} -lh
    echo -e "\n\e[36m Done. \e[0m"
}


pack_loader_image
finish
