#set -x

BUILD=build
rm -rf $BUILD
mkdir -p $BUILD

ROOTFS_DIR=$BUILD/rootfs
mkdir -p $ROOTFS_DIR

ROOTFS_MNT=$BUILD/mnt

ROOTFS_IMG=$BUILD/rootfs.img


# build docker
echo -e "\e[36m Building images \e[0m"
docker build -t rk3399 .
id=$(docker create rk3399)
echo -e "\e[36m Copy tarball from docker container \e[0m"
docker cp $id:/boot.tar $BUILD/boot.tar
docker rm -fv $id
tar xf $BUILD/boot.tar -C $BUILD
rm $BUILD/boot.tar

sync


finish () {
    umount $ROOTFS_DIR/proc >/dev/null 2>&1
    umount $ROOTFS_DIR/sys >/dev/null 2>&1
    umount $ROOTFS_DIR/dev/pts >/dev/null 2>&1
    umount $ROOTFS_DIR/dev >/dev/null 2>&1

    umount $ROOTFS_MNT >/dev/null 2>&1

    rm -rf $ROOTFS_DIR
    rm -rf $ROOTFS_MNT

    mv -f $BUILD/99-rk-rockusb.rules /etc/udev/rules.d/.
    echo -e "\e[36m Done. \e[0m"
    ls $BUILD -lh
}
trap finish EXIT

# build ubuntu-rootfs
cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin
echo "nameserver 8.8.8.8" > $ROOTFS_DIR/etc/resolv.conf

mount -t proc /proc $ROOTFS_DIR/proc
mount -t sysfs /sys $ROOTFS_DIR/sys
mount -o bind /dev $ROOTFS_DIR/dev
mount -o bind /dev/pts $ROOTFS_DIR/dev/pts		

cat << EOF | chroot $ROOTFS_DIR/
#chroot $ROOTFS_DIR/

#apt update
#apt upgrade
apt-get install -y udev sudo ssh language-pack-en-base --no-install-recommends 
apt-get install -y systemd --no-install-recommends 

# 必须安装systemd，否则系统无法挂载
apt-get install -y ifupdown net-tools network-manager  ethtool --no-install-recommends 
apt-get install -y vim rsyslog  bash-completion htop --no-install-recommends
# 无线网络配置工具
apt-get install -y wireless-tools wpasupplicant iputils-ping --no-install-recommends 

systemctl enable rockchip.service
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service

HOST=oiramario
echo "$HOST" > /etc/hostname

echo "\
127.0.0.1 $HOST
127.0.0.1 localhost.localdomain localhost" > /etc/hosts

mkdir -p /etc/network/interfaces.d
echo "\
auto eth0
iface eth0 inet dhcp" > /etc/network/interfaces.d/eth0

#echo "\
#start on stopped rc or RUNLEVEL=[12345]
#stop on RUNLEVEL [!12345]
#respawn
#exec /sbin/getty -L 115200 ttyS0 vt102" > /etc/init/ttyS0.conf

EOF

umount $ROOTFS_DIR/proc
umount $ROOTFS_DIR/sys
umount $ROOTFS_DIR/dev/pts
umount $ROOTFS_DIR/dev

sync


# build rootfs.img
dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=512
mkfs.ext4 $ROOTFS_IMG
mkdir -p $ROOTFS_MNT
mount $ROOTFS_IMG $ROOTFS_MNT
cp -a $ROOTFS_DIR/* $ROOTFS_MNT
umount $ROOTFS_MNT
e2fsck -p -f $ROOTFS_IMG
resize2fs -M $ROOTFS_IMG
