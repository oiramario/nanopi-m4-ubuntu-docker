# Functions:
# pack_qemu_image

source functions/common.sh

set -x
pack_qemu_image()
{
    cd ${BUILD}/qemu-u-boot
    # u-boot.bin
    cp -v ./u-boot.bin ${DISTRO}/qemu-u-boot.bin
    # boot.scr
    ./tools/mkimage -C none -A arm64 -T script -d \
        ${HOME}/scripts/boot/qemu_boot.cmd ${DISTRO}/boot.scr
    # uImage
    ./tools/mkimage -A arm64 -O linux -T kernel -C none -a 0x81008000 -e 0x81008000 -n Linux -d \
        ${BUILD}/kernel-rockchip/arch/arm64/boot/Image.gz ${DISTRO}/uImage

    # 32M
    echo
   	info_msg "creating the empty image"
    local image=${DISTRO}/qemu-boot.img
    rm -f ${image}
    dd if=/dev/zero of=${image} bs=1M count=128
    mknod -m 0660 /dev/loop100 b 7 100
    local devloop=/dev/loop100
    losetup /dev/loop100 ${image}

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
    partprobe ${image}
    sleep 1
    sync

    echo
   	info_msg "formatting and mounting"
    # 2048 * 512 = 1048576
    mknod -m 0660 /dev/loop101 b 7 101
    local partloop=/dev/loop101
    losetup -o 1048576 ${partloop} ${image}
    mkfs.ext4 ${partloop}
    local mnt=/tmp/boot-mnt
    rm -rf ${mnt}
    mkdir -p ${mnt}
    mount ${partloop} ${mnt}

    echo
   	info_msg "copying data"
    cp -v ${DISTRO}/boot.scr ${mnt}/
    cp -v ${DISTRO}/uImage ${mnt}/
#    cp -v /tmp/boot/uImage/fitImage.itb ${mnt}/

    echo
   	info_msg "cleaning up"
    umount ${mnt}
    losetup -d ${partloop}
    losetup -d ${devloop}
    sync
}
