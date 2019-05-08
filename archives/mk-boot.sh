#!/bin/bash
#
set -x

rm -f $DISTRO/MiniLoaderAll.bin
rm -f $DISTRO/idbloader.img
rm -f $DISTRO/trust.img
rm -f $DISTRO/uboot.img
rm -f $DISTRO/boot.img

# boot loader
#----------------------------------------------------------------------------------------------------------------#
cd $BUILD/rkbin
cp idbloader.img uboot.img trust.img $DISTRO/
cp rk3399_loader_*.bin $DISTRO/MiniLoaderAll.bin


# boot.img
#----------------------------------------------------------------------------------------------------------------#
BOOT=/tmp/boot
rm -rf $BOOT
mkdir -p $BOOT
cd $BUILD/kernel-rockchip/arch/arm64/boot

# kernel
cp Image.gz $BOOT/kernel.gz

# dtb
cp dts/rockchip/rk3399-nanopi4-rev0*.dtb $BOOT/

# initramfs
INITRAMFS=$BOOT/initramfs
rm -rf $INITRAMFS
mkdir -p $INITRAMFS
cp -rf $BUILD/initramfs/* $INITRAMFS/

# dptx.bin
cd /tmp
tar xzf $HOME/packages/rk-rootfs-build.tar.gz rk-rootfs-build/overlay-firmware/lib/firmware/rockchip
mkdir -p $INITRAMFS/lib/firmware/rockchip
cp /tmp/rk-rootfs-build/overlay-firmware/lib/firmware/rockchip/dptx.bin $INITRAMFS/lib/firmware/rockchip

# ramdisk.cpio.gz
cd $INITRAMFS
rm linuxrc
cp $HOME/archives/init .
find . | cpio -o -H newc | gzip > $BOOT/ramdisk.cpio.gz

# FIT
FIT=$BOOT/fit
rm -rf $FIT
mkdir -p $FIT
cp $HOME/archives/boot.cmd $HOME/archives/rk3399-fit.its $BOOT/
$BUILD/u-boot/tools/mkimage -C none -A arm64 -T script -d $BOOT/boot.cmd $FIT/boot.scr
$BUILD/u-boot/tools/mkimage -f $BOOT/rk3399-fit.its $FIT/fit.itb

# make image
BOOT_IMG=$DISTRO/boot.img
genext2fs -b 65536 -d $FIT $BOOT_IMG
e2fsck -p -f $BOOT_IMG
resize2fs -M $BOOT_IMG

echo -e "\n\e[36m Done. \e[0m"
