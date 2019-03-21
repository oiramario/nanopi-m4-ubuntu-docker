BUILD=build
rm -rf ${BUILD}
mkdir -p ${BUILD}

ROOTFS=${BUILD}/rootfs
mkdir -p ${ROOTFS}

echo -e "\e[36m Building images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
echo -e "\e[36m Copy tarball from docker container \e[0m"
docker cp $id:/boot.tar ${BUILD}/boot.tar
docker rm -fv $id
sync


echo -e "\e[36m Making rootfs.img \e[0m"
dd if=/dev/zero of=${BUILD}/rootfs.img bs=1M count=256
mkfs.ext4 ${BUILD}/rootfs.img
sync
mount ${BUILD}/rootfs.img ${ROOTFS}
echo -e "\e[36m Extracting tarball \e[0m"
tar xf ${BUILD}/boot.tar -C ${BUILD}
sync
umount ${ROOTFS}
sleep 1
e2fsck -p -f ${BUILD}/rootfs.img
resize2fs -M ${BUILD}/rootfs.img
sync

mv -f ${BUILD}/99-rk-rockusb.rules /etc/udev/rules.d/.

rm -rf ${ROOTFS}
rm ${BUILD}/boot.tar
echo -e "\e[36m Done. \e[0m"
ls ${BUILD} -lh
