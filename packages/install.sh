#set -x
if [ ! -d src ];then
    mkdir src
fi
cd src

echo -e "\e[34m checking rkbin ... \e[0m"
if [ ! -d rkbin ];then
    git clone --depth 1 -b master https://github.com/rockchip-linux/rkbin.git rkbin
else
    cd rkbin
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking u-boot ... \e[0m"
if [ ! -d u-boot ];then
    git clone --depth 1 -b master https://github.com/u-boot/u-boot.git u-boot
else
    cd u-boot
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking kernel ... \e[0m"
if [ ! -d kernel ];then
    git clone --depth 1 -b nanopi4-linux-v4.4.y https://github.com/friendlyarm/kernel-rockchip.git kernel
else
    cd kernel
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking busybox ... \e[0m"
if [ ! -d busybox ];then
    git clone --depth 1 -b 1_30_stable https://github.com/mirror/busybox.git busybox
else
    cd busybox
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking rk-rootfs-build ... \e[0m"
if [ ! -d rk-rootfs-build ];then
    git clone --depth 1 -b master https://github.com/rockchip-linux/rk-rootfs-build.git rk-rootfs-build
else
    cd rk-rootfs-build
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking libmali ... \e[0m"
if [ ! -d libmali ];then
    git clone --depth 1 -b rockchip https://github.com/rockchip-linux/libmali.git libmali
else
    cd libmali
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"


echo -e "\e[34m checking libdrm ... \e[0m"
if [ ! -d libdrm ];then
    git clone --depth 1 -b rk33/mid/9.0/develop https://github.com/rockchip-linux/libdrm-rockchip.git libdrm
else
    cd libdrm
    git pull
    cd ..
fi
echo -e "\e[32m done.\n \e[0m"

echo
sub_dirs=`ls -d *`
for dir in $sub_dirs
do
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
