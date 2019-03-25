BUILD=build
rm -rf ${BUILD}
mkdir -p ${BUILD}

ROOTFS=${BUILD}/rootfs
mkdir -p ${ROOTFS}

# build docker
echo -e "\e[36m Building images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
echo -e "\e[36m Copy tarball from docker container \e[0m"
docker cp $id:/boot.tar ${BUILD}/boot.tar
docker rm -fv $id
tar xf ${BUILD}/boot.tar -C ${BUILD}
sync

# build ubuntu-rootfs
cp /usr/bin/qemu-aarch64-static ${ROOTFS}/usr/bin
cp -f /etc/resolv.conf ${ROOTFS}/etc/resolv.conf
cp -f /etc/apt/sources.list ${ROOTFS}/etc/apt/sources.list

mount -t proc /proc ${ROOTFS}/proc
mount -t sysfs /sys ${ROOTFS}/sys
mount -o bind /dev ${ROOTFS}/dev
mount -o bind /dev/pts ${ROOTFS}/dev/pts		

cat << EOF | chroot ${ROOTFS}/

apt-get update

EOF

umount ${ROOTFS}/proc
umount ${ROOTFS}/sys
umount ${ROOTFS}/dev/pts
umount ${ROOTFS}/dev

# make rootfs.img
rm -f rootfs.img
dd if=/dev/zero of=${BUILD}/rootfs.img bs=1M count=512
mkfs.ext4 ${BUILD}/rootfs.img
mkdir  ubuntu-mount
mount ${BUILD}/rootfs.img ubuntu-mount/
cp -rfp ${ROOTFS}/*  ubuntu-mount/
umount ubuntu-mount/
e2fsck -p -f ${BUILD}/rootfs.img
resize2fs -M ${BUILD}/rootfs.img
sync


# clean
rm -rf ubuntu-mount
rm -rf ${ROOTFS}
rm ${BUILD}/boot.tar

mv -f ${BUILD}/99-rk-rockusb.rules /etc/udev/rules.d/.
echo -e "\e[36m Done. \e[0m"
ls ${BUILD} -lh
