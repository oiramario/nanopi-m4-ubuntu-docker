#set -x

if [ ! -d src ];then
    mkdir src
fi
cd src

sources=(
"master,https://github.com/rockchip-linux/rkbin.git,rkbin"
"master,https://github.com/u-boot/u-boot.git,u-boot"
"nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
"1_30_stable,https://github.com/mirror/busybox.git,busybox"
"master,https://github.com/rockchip-linux/rk-rootfs-build.git,rk-rootfs-build"
"rockchip,https://github.com/rockchip-linux/libmali.git,libmali"
"rk33/mid/9.0/develop,https://github.com/rockchip-linux/libdrm-rockchip.git,libdrm-rockchip"
"master,https://github.com/gentoo/eudev.git,eudev"
"master,https://github.com/libusb/libusb.git,libusb"
"master,https://github.com/IntelRealSense/librealsense.git,librealsense"
"master,https://github.com/oiramario/gbm-drm-gles-cube.git,gbm-drm-gles-cube"
)
for i in ${sources[@]}
do
    IFS=","
    arr=($i)

    echo -e "\e[34m checking ${arr[2]} ... \e[0m"
    if [ ! -d ${arr[2]} ];then
        git clone --depth 1 -b ${arr[0]} ${arr[1]} ${arr[2]}
    else
        cd ${arr[2]}
        git pull
        cd ..
    fi

    dir=${arr[2]}
    package=../$dir.tar
    echo -e "\e[34m pack $dir ... \e[0m"
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
    elif [ $dir = "rk-rootfs-build" ];then
        tar --exclude=usr/share/npu_fw -cf $package $dir/overlay-firmware
    else
        tar --exclude=.git -cf $package $dir
    fi

    echo -e "\e[33m compressing ... \e[0m"
    xz -zef --threads=0 $package
    echo -e "\e[32m done.\n \e[0m"
done
