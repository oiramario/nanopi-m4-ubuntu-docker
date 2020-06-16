# Functions:
# pack_rootfs_image

source functions/common.sh


pack_rootfs_image()
{
    # ubuntu rootfs
    echo
   	info_msg "ubuntu rootfs"
    local rootfs=/tmp/rootfs
    if [ -d ${rootfs} ];then
        umount ${rootfs}/proc/sys/fs/binfmt_misc > /dev/null 2>&1
        umount ${rootfs}/proc > /dev/null 2>&1
        umount ${rootfs}/sys > /dev/null 2>&1
        umount ${rootfs}/dev/pts > /dev/null 2>&1
        umount ${rootfs}/dev > /dev/null 2>&1
        rm -rf ${rootfs}
    fi
    mkdir -p ${rootfs}
    cp -rfp ${ROOTFS}/* ${rootfs}/

    # kernel modules
    # echo
   	# info_msg "copy kernel modules"
    # cp -rf ${BUILD}/kmodules/* ${rootfs}/

    # mount
    echo
   	info_msg "mount"
    mount -t proc /proc ${rootfs}/proc
    mount -t sysfs /sys ${rootfs}/sys
    mount -o bind /dev ${rootfs}/dev
    mount -o bind /dev/pts ${rootfs}/dev/pts
    mount binfmt_misc -t binfmt_misc ${rootfs}/proc/sys/fs/binfmt_misc
    update-binfmts --enable qemu-aarch64

    # building
    echo
   	info_msg "building rootfs"
    cp -v /usr/bin/qemu-aarch64-static ${rootfs}/usr/bin/
    cat << EOF | LC_ALL=C LANG=C chroot ${rootfs}/ /bin/bash
set -x

uname -a
cat /proc/version
cat /etc/issue

passwd root
root
root

useradd -m -s /bin/bash flagon
passwd flagon
111
111
usermod -aG sudo flagon

export DEBIAN_FRONTEND=noninteractive 

apt-get update
apt-get upgrade -y

apt-get install -y --no-install-recommends --no-install-suggests -o Dpkg::Options::="--force-confold" \
                --allow-downgrades --allow-remove-essential --allow-change-held-packages \
                init dbus rsyslog kmod systemd

apt-get install -y --no-install-recommends --no-install-suggests -o Dpkg::Options::="--force-confold" \
                --allow-downgrades --allow-remove-essential --allow-change-held-packages \
                network-manager rfkill iputils-ping bluetooth bluez bluez-tools alsa-base alsa-utils

apt-get install -y --no-install-recommends --no-install-suggests -o Dpkg::Options::="--force-confold" \
                --allow-downgrades --allow-remove-essential --allow-change-held-packages \
                pm-utils triggerhappy sudo ssh htop file mlocate bash-completion vim

echo "AllowUsers flagon" >> /etc/ssh/sshd_config

systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

apt-get autoclean -y
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/log/*
rm -rf /tmp/*
EOF
    rm ${rootfs}/usr/bin/qemu-aarch64-static
    sync
    umount ${rootfs}/proc/sys/fs/binfmt_misc
    umount ${rootfs}/proc
    umount ${rootfs}/sys
    umount ${rootfs}/dev/pts
    umount ${rootfs}/dev
    sync


    # make rootfs.img
    echo
   	info_msg "make rootfs.img"
    local rootfs_mnt=/tmp/rootfs-mnt
    [ -d ${rootfs_mnt} ] && rm -rf ${rootfs_mnt}
    local rootfs_img=${DISTRO}/rootfs.img
    [ -f ${rootfs_img} ] && rm -f ${rootfs_img}

    dd if=/dev/zero of=${rootfs_img} bs=1M count=1024
    mkfs.ext4 ${rootfs_img}
    sync
    mkdir -p ${rootfs_mnt}
    mount ${rootfs_img} ${rootfs_mnt}
    if [ $? -eq 0 ] ; then
        cp -rfp ${rootfs}/* ${rootfs_mnt}
        umount ${rootfs_mnt}
        e2fsck -p -f ${rootfs_img}
        resize2fs -M ${rootfs_img}
    else
        error_msg "something wrong..."
    fi
}
