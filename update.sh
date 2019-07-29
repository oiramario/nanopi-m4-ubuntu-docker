#!/bin/bash
#
#set -x

GITS_DIR=$PWD/gits
PACKAGES_DIR=$PWD/packages

[ ! -d $GITS_DIR ] && mkdir -p $GITS_DIR

[ ! -d $PACKAGES_DIR ] && mkdir -p $PACKAGES_DIR

cd $GITS_DIR

gits=(
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/rkbin.git,rkbin"
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/u-boot.git,u-boot"
"nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
"1_30_stable,https://github.com/mirror/busybox.git,busybox"
"master,https://github.com/friendlyarm/rk-rootfs-build.git,rk-rootfs-build"
"rockchip,https://github.com/rockchip-linux/libmali.git,libmali"
#"master,https://github.com/IntelRealSense/librealsense.git,librealsense"
#"master,https://github.com/oiramario/gbm-drm-gles-cube.git,gbm-drm-gles-cube"
)
for i in ${gits[@]}
do
    IFS=","
    arr=($i)

    branch=${arr[0]}
    url=${arr[1]}
    dir=${arr[2]}

    echo -e "\e[34m checking $dir ... \e[0m"
    if [ ! -d $dir ];then
        git clone --depth 1 -b $branch $url ${dir}
    else
        if [[ `git -C $dir pull` =~ "Already up to date." ]];then
            echo up-to-date sources.
            if [ -f $PACKAGES_DIR/$dir.tar.gz ]; then
                echo up-to-date package.
                continue
            fi
        fi
    fi

    echo -e "\e[34m packing $dir ... \e[0m"
    option=
    if [ $dir = "libmali" ];then
        option="\
            --exclude=lib/arm-linux-gnueabihf \
            --exclude=lib/aarch64-linux-gnu/libmali-bifrost-* \
            --exclude=lib/aarch64-linux-gnu/libmali-utgard-* \
            --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r9p0-* \
            --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r13p0-* \
            --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-fbdev.so \
            --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-wayland-gbm.so \
            --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-x11.so"
    elif [ $dir = "rk-rootfs-build" ];then
        option="\
            --exclude=overlay-debug \
            --exclude=overlay-firmware/usr/share/npu_fw \
            --exclude=packages/armhf \
            --exclude=packages/arm64/others \
            --exclude=packages/arm64/video \
            --exclude=packages/arm64/xserver \
            --exclude=packages-patches \
            --exclude=ubuntu-build-service"
    fi

    eval tar --exclude-vcs $option -czf $PACKAGES_DIR/$dir.tar.gz $dir

    echo -e "\e[32m done.\n \e[0m"
done

echo -e "\e[34m checking ubuntu-rootfs ... \e[0m"
if [ ! -f $PACKAGES_DIR/ubuntu-rootfs.tar.gz ]; then
    wget -O $PACKAGES_DIR/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz
else
    echo ubuntu-rootfs exists.
fi
