#!/bin/bash
#
#set -x

DISTRO_DIR=$PWD/distro
TOOLS_DIR=$PWD/tools

if [ ! -f "/etc/udev/rules.d/99-rk-rockusb.rules" ]; then
    echo -e "\e[36m add rockusb rules to udev \e[0m"
    sudo cp -f $TOOLS_DIR/99-rk-rockusb.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi


echo -e "\e[36m DownloadBoot MiniLoaderAll.bin \e[0m"
$TOOLS_DIR/rkdeveloptool db          $DISTRO_DIR/MiniLoaderAll.bin
sleep 2

#echo -e "\e[36m UpgradeLoader MiniLoaderAll.bin \e[0m"
#$TOOLS_DIR/rkdeveloptool ul          $DISTRO_DIR/MiniLoaderAll.bin
#sleep 1

#echo -e "\e[36m WriteGPT parameter.gpt \e[0m"
#$TOOLS_DIR/rkdeveloptool gpt         $TOOLS_DIR/parameter.gpt
#sleep 1

#echo -e "\e[36m WriteLBA 0x40 idbloader.img \e[0m"
#$TOOLS_DIR/rkdeveloptool wl 0x40     $DISTRO_DIR/idbloader.img
#sleep 1

#echo -e "\e[36m WriteLBA 0x4000 uboot.img \e[0m"
#$TOOLS_DIR/rkdeveloptool wl 0x4000   $DISTRO_DIR/uboot.img
#sleep 1

#echo -e "\e[36m WriteLBA 0x6000 trust.img \e[0m"
#$TOOLS_DIR/rkdeveloptool wl 0x6000   $DISTRO_DIR/trust.img
#sleep 1

echo -e "\e[36m WriteLBA 0x8000 boot.img \e[0m"
$TOOLS_DIR/rkdeveloptool wl 0x8000   $DISTRO_DIR/boot.img
sleep 1

echo -e "\e[36m WriteLBA 0x20000 rootfs.img \e[0m"
$TOOLS_DIR/rkdeveloptool wl 0x20000  $DISTRO_DIR/rootfs.img
sleep 1

echo -e "\e[36m ResetDevice \e[0m"
$TOOLS_DIR/rkdeveloptool rd
