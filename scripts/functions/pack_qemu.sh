# Functions:
# pack_qemu_image

source functions/common.sh


pack_qemu_image()
{
    # 32M
    echo
   	info_msg "creating the empty image"
    local image=/tmp/qemu_boot.img
    rm -f ${image}
    dd if=/dev/zero of=${image} bs=1M count=64
    local devloop=`losetup -f`
    losetup ${devloop} ${image}

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
    partprobe ${image}

    echo
   	info_msg "formatting and mounting"
    # 2048 * 512 = 1048576
    local partloop=`losetup -f`
    losetup -o 1048576 ${partloop} ${devloop}
    mkfs.ext4 ${partloop}
    mkdir -p /tmp/boot-mnt
    mount ${partloop} /tmp/boot-mnt/

    echo
   	info_msg "copying data"
    cp -v ${DISTRO}/boot.scr /tmp/boot-mnt/
    cp -v ${DISTRO}/fitImage.itb /tmp/boot-mnt/
    cp -v ${DISTRO}/Image /tmp/boot-mnt/

    echo
   	info_msg "cleaning up"
    umount /tmp/boot-mnt/
    losetup -d ${partloop}
    losetup -d ${devloop}
}
