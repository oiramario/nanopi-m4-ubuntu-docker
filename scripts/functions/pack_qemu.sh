# Functions:
# pack_qemu_image

source functions/common.sh


pack_qemu_image()
{
    # u-boot.bin
    echo
   	info_msg "u-boot.bin"
    cp -v ${BUILD}/qemu/roms/u-boot/u-boot.bin ${DISTRO}/qemu-u-boot.bin

    # boot loader
    local boot=/tmp/qemu_boot
    [ -d ${boot} ] && rm -rf ${boot}
    mkdir -p ${boot}

    # boot
    cd ${BUILD}/kernel-rockchip/arch/arm64/boot
    ## kernel
    echo
   	info_msg "kernel"
    cp -v ./Image.gz ${boot}/kernel.gz
    ## dtb
    echo
   	info_msg "dtb"
    cp -v dts/rockchip/rk3399-nanopi4-rev01.dtb ${boot}/

    # initramfs
    echo
   	info_msg "initramfs"
    local ramdisk=/tmp/qemu_ramdisk
    [ -d ${ramdisk} ] && rm -rf ${ramdisk}
    mkdir -p ${ramdisk}
    cd ${ramdisk}
    ## busybox
    cp -rf ${BUILD}/initramfs/* ./
    ## dptx.bin
    local dptx_src=${BUILD}/rk-rootfs-build/overlay-firmware/lib/firmware/rockchip/dptx.bin
    local dptx_dst=${ramdisk}/lib/firmware/rockchip
    mkdir -p ${dptx_dst}
    cp -vf ${dptx_src} ${dptx_dst}
    ## ramdisk.cpio.gz
    rm -f linuxrc
    cp -f ${HOME}/scripts/boot/init ./
    find . | cpio -oH newc | gzip > ${boot}/ramdisk.cpio.gz

    # FIT
    echo
   	info_msg "flattened device tree"
    cd ${HOME}/scripts/boot
    cp -v qemu_boot.cmd qemu_fitImage.its ${boot}/
    ## binary path
    local fit_path=${boot}/uImage
    [ -d ${fit_path} ] && rm -rf ${fit_path}
    mkdir -p ${fit_path}
    ## mkimage
    cd ${BUILD}/qemu/roms/u-boot/tools
   	info_msg "boot.scr"
    ./mkimage -C none -A arm64 -T script -d ${boot}/qemu_boot.cmd ${fit_path}/boot.scr
   	info_msg "fitImage.itb"
    ./mkimage -f ${boot}/qemu_fitImage.its ${fit_path}/fitImage.itb

    # 32M
    echo
   	info_msg "creating the empty image"
    local boot_img=${DISTRO}/qemu-boot.img
    rm -f ${boot_img}
    dd if=/dev/zero of=${boot_img} bs=1M count=32
    mknod -m 0660 /dev/loop100 b 7 100
    local devloop=/dev/loop100
    losetup /dev/loop100 ${boot_img}

    echo
   	info_msg "running fdisk to partition the card"
    cat << EOF | fdisk ${devloop}
    g
    n
    1
    2048
    65502
    t
    83
    p
    w
EOF
    sync

    echo
   	info_msg "formatting and mounting"
    # 2048 * 512 = 1048576
    mknod -m 0660 /dev/loop101 b 7 101
    local partloop=/dev/loop101
    losetup -o 1048576 ${partloop} ${boot_img}
    mkfs.ext4 ${partloop}
    local mnt=/tmp/boot-mnt
    rm -rf ${mnt}
    mkdir -p ${mnt}
    mount ${partloop} ${mnt}

    echo
   	info_msg "copying data"
    cp -v ${fit_path}/boot.scr ${mnt}/
    cp -v ${fit_path}/fitImage.itb ${mnt}/

    echo
   	info_msg "cleaning up"
    umount ${mnt}
    losetup -d ${partloop}
    losetup -d ${devloop}
    sync
}
