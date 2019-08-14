#!/bin/bash
#
#set -x

gits_dir=$(pwd)/gits
[ ! -d $gits_dir ] && mkdir -p $gits_dir

packages_dir=$(pwd)/packages
[ ! -d $packages_dir ] && mkdir -p $packages_dir

cd $gits_dir

gits=(
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/rkbin.git,rkbin"
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/u-boot.git,u-boot"
"nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
"1_30_stable,https://github.com/mirror/busybox.git,busybox"
"master,https://github.com/rockchip-linux/rk-rootfs-build.git,rk-rootfs-build"
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
            if [ -f $packages_dir/$dir.tar.gz ]; then
                echo up-to-date package.
                continue
            fi
        fi
    fi

    echo -e "\e[34m packing $dir ... \e[0m"
    exclude="--exclude-vcs"
    if [ $dir = "rk-rootfs-build" ];then
        exclude+=" \
            --exclude=*.md \
            --exclude=$dir/mk-*.sh \
            --exclude=overlay-firmware/usr/share/npu_fw \
            --exclude=packages/armhf \
            --exclude=packages/arm64/others \
            --exclude=packages/arm64/video \
            --exclude=packages/arm64/xserver \
            --exclude=packages/arm64/libmali/libmali-rk-bifrost-*.deb \
            --exclude=packages-patches \
            --exclude=ubuntu-build-service"
    fi

    eval tar -czf $packages_dir/$dir.tar.gz $exclude -C . $dir

    echo -e "\e[32m done.\n \e[0m"
done

echo -e "\e[34m checking ubuntu-rootfs ... \e[0m"
if [ ! -f $packages_dir/ubuntu-rootfs.tar.gz ]; then
    wget -O $packages_dir/ubuntu-rootfs.tar.gz http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz
else
    echo ubuntu-rootfs exists.
fi

echo -e "\e[34m checking qemu ... \e[0m"
if [ ! -f $packages_dir/qemu.tar.xz ]; then
    wget -O $packages_dir/qemu.tar.xz https://download.qemu.org/qemu-4.0.0.tar.xz
else
    echo qemu exists.
fi
