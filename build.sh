WORKPATH=/opt
rm -rf ${WORKPATH}
sync

PACKAGES=${WORKPATH}/packages
mkdir -p ${PACKAGES}
sync

OUTPUT=${WORKPATH}/rk3399
mkdir -p ${OUTPUT}
sync

ROOTFS=${OUTPUT}/rootfs
mkdir -p ${ROOTFS}
sync

echo -e "\e[32m Building images \033[0m"
docker build -t rk3399 .
docker create -ti --name dummy rk3399 bash
echo -e "\e[32m Copy tarball from docker container \033[0m"
docker cp dummy:/boot.tar ${PACKAGES}/boot.tar
docker rm -fv dummy
sync

echo -e "\e[32m Making rootfs.img \033[0m"
dd if=/dev/zero of=${OUTPUT}/rootfs.img bs=1M count=512
mkfs.ext4 ${OUTPUT}/rootfs.img
sync
mount ${OUTPUT}/rootfs.img ${ROOTFS}
echo -e "\e[32m Extracting tarball \033[0m"
tar xf ${PACKAGES}/boot.tar -C ${OUTPUT}
sync
umount ${ROOTFS}
sleep 1
e2fsck -p -f ${OUTPUT}/rootfs.img
resize2fs -M ${OUTPUT}/rootfs.img
sync

rm -rf ${PACKAGES} ${ROOTFS}
echo -e "\e[33m Done. \e[0m"
ls ${OUTPUT} -lh

#echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666",GROUP="plugdev"' | sudo tee /etc/udev/rules.d/99-rk-rockusb.rules
#sudo udevadm control --reload-rules
#sudo udevadm trigger
