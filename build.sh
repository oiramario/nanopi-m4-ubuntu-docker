WORKPATH=/opt/rk3399
rm -rf ${WORKPATH}
sync

PACKAGES=${WORKPATH}/packages
mkdir -p ${PACKAGES}
sync

OUTPUT=${WORKPATH}/output
mkdir -p ${OUTPUT}
sync

ROOTFS=${OUTPUT}/rootfs
mkdir -p ${ROOTFS}
sync

echo -e "\e[32m Building images \033[0m"
docker build --build-arg CORES=$(sed -n "N;/processor/p" /proc/cpuinfo|wc -l) -t rk3399 .
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
tree ${OUTPUT} -h

#echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0666",GROUP="plugdev"' | sudo tee /etc/udev/rules.d/99-rk-rockusb.rules
#sudo udevadm control --reload-rules
#sudo udevadm trigger

# cd ${OUTPUT}

#./rkdeveloptool db rk3399_loader_v1.18.118.bin
#./rkdeveloptool ul rk3399_loader_v1.18.118.bin

#./rkdeveloptool gpt parameter_gpt.txt

#./rkdeveloptool wl 0x40    idbloader.img
#./rkdeveloptool wl 0x4000  uboot.img
#./rkdeveloptool wl 0x6000  trust.img
#./rkdeveloptool wl 0x8000  boot.img
#./rkdeveloptool wl 0x40000 rootfs.img

#./rkdeveloptool rd
