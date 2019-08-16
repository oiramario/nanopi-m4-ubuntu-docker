# Functions:
# pack_qemu_image

source functions/common.sh

set -x
pack_qemu_image()
{
    cp -v ${BUILD}/qemu-u-boot/u-boot.bin ${DISTRO}/qemu-u-boot.bin

    # 32M
    echo
   	info_msg "creating the empty image"
    local image=${DISTRO}/qemu-boot.img
    rm -f ${image}
    dd if=/dev/zero of=${image} bs=1M count=64
    local devloop=$(losetup --show -f ${image})

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
#    partprobe ${image}

    echo
   	info_msg "formatting and mounting"
    # 2048 * 512 = 1048576
    local partloop=$(losetup -f)
    losetup -o 1048576 ${partloop} ${devloop}
    mkfs.ext4 ${partloop}
    local mnt=/tmp/boot-mnt
    rm -rf ${mnt}
    mkdir -p ${mnt}
    mount ${partloop} ${mnt}

    echo
   	info_msg "copying data"
    cp -v /tmp/boot/uImage/boot.scr ${mnt}/
    cp -v /tmp/boot/uImage/fitImage.itb ${mnt}/

    cp -v ${BUILD}/kernel-rockchip/arch/arm64/boot/Image ${mnt}/
    cp -v ${BUILD}/kernel-rockchip/arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev04.dtb ${mnt}/
    cp -v /tmp/boot/ramdisk.cpio.gz ${mnt}/

    echo
   	info_msg "cleaning up"
    umount ${mnt}
    losetup -d ${partloop}
    losetup -d ${devloop}
}
