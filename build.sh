PACKAGES=/tmp/packages
mkdir -p ${PACKAGES}

OUTPUT=/tmp/output
mkdir -p ${OUTPUT}

ROOTFS=${OUTPUT}/rootfs
mkdir -p ${ROOTFS}

echo -e "\e[32m Building images \033[0m"
docker build -t rk3399 .
docker create -ti --name dummy rk3399 bash
echo -e "\e[32m Copy tarball from docker container \033[0m"
docker cp dummy:/boot.tar ${PACKAGES}/boot.tar
docker rm -fv dummy

echo -e "\e[32m Making rootfs.img \033[0m"
dd if=/dev/zero of=${OUTPUT}/rootfs.img bs=1M count=512
mkfs.ext4 ${OUTPUT}/rootfs.img
mount ${OUTPUT}/rootfs.img ${ROOTFS}
echo -e "\e[32m Extracting tarball \033[0m"
tar xf ${PACKAGES}/boot.tar -C ${OUTPUT}
umount ${ROOTFS}
e2fsck -p -f ${OUTPUT}/rootfs.img
resize2fs -M ${OUTPUT}/rootfs.img

rm -rf ${PACKAGES} ${ROOTFS}
echo -e "\e[33m Done. \e[0m"
tree ${OUTPUT} -h
