#!/bin/bash
#
set -x

gits=(
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/rkbin.git,rkbin"
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/u-boot.git,u-boot"
"nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
"1_30_stable,https://github.com/mirror/busybox.git,busybox"
"master,https://github.com/friendlyarm/rk-rootfs-build.git,rk-rootfs-build"
"rockchip,https://github.com/rockchip-linux/libmali.git,libmali"
"master,https://github.com/IntelRealSense/librealsense.git,librealsense"
"master,https://github.com/oiramario/gbm-drm-gles-cube.git,gbm-drm-gles-cube"
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
            if [ -f $dir.tar.xz ]; then
                continue
            fi
        fi
    fi

    if [ ! $dir = "rk-rootfs-build" ];then
        echo -e "\e[34m packing $dir ... \e[0m"
        package=$dir.tar
        if [ $dir = "libmali" ];then
            tar --exclude=.git \
                --exclude=lib/arm-linux-gnueabihf \
                --exclude=lib/aarch64-linux-gnu/libmali-bifrost-* \
                --exclude=lib/aarch64-linux-gnu/libmali-utgard-* \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r9p0-* \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r13p0-* \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-fbdev.so \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-wayland-gbm.so \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-x11.so \
                --exclude=lib/aarch64-linux-gnu/libmali-midgard-t86x-r14p0-r0p0-x11-gbm.so \
                -cf $package $dir
        else
            tar --exclude=.git -cf $package $dir
        fi

        echo -e "\e[33m compressing ... \e[0m"
        xz -zef --threads=0 $package
    fi

    echo -e "\e[32m done.\n \e[0m"
done
