#set -x

REDIST=redist
rm -rf $REDIST
mkdir -p $REDIST

ROOTFS_DIR=$REDIST/rootfs
ROOTFS_MNT=$REDIST/rootfs-mnt
ROOTFS_IMG=$REDIST/rootfs.img

BOOT_DIR=$REDIST/boot
BOOT_MNT=$REDIST/boot-mnt
BOOT_IMG=$REDIST/boot.img


# build docker
echo -e "\e[36m Building images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
echo -e "\e[36m Copy tarball from docker container \e[0m"
docker cp $id:/redist.tar $REDIST/redist.tar
docker rm -fv $id
tar xf $REDIST/redist.tar -C $REDIST
rm $REDIST/redist.tar
sync


finish () {
    umount $ROOTFS_MNT >/dev/null 2>&1
    rm -rf $ROOTFS_MNT
    rm -rf $ROOTFS_DIR

    umount $BOOT_MNT >/dev/null 2>&1
    rm -rf $BOOT_MNT
    rm -rf $BOOT_DIR

    mv -f $REDIST/99-rk-rockusb.rules /etc/udev/rules.d/.
    echo -e "\e[36m Done. \e[0m"
    ls $REDIST -lh
}
trap finish EXIT


# build boot.img
dd if=/dev/zero of=$BOOT_IMG bs=1M count=24
mkfs.ext2 $BOOT_IMG
mkdir -p $BOOT_MNT
mount $BOOT_IMG $BOOT_MNT
cp -a $BOOT_DIR/* $BOOT_MNT
sync
umount $BOOT_MNT
e2fsck -p -f $BOOT_IMG
resize2fs -M $BOOT_IMG



# build rootfs.img
dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=128
mkfs.ext4 $ROOTFS_IMG
mkdir -p $ROOTFS_MNT
mount $ROOTFS_IMG $ROOTFS_MNT
cp -a $ROOTFS_DIR/* $ROOTFS_MNT
sync
umount $ROOTFS_MNT
e2fsck -p -f $ROOTFS_IMG
resize2fs -M $ROOTFS_IMG
