# configure
#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.2" \
      email="oiramario@gmail.com"

# apt sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/" \
    && echo "\
deb $SOURCES bionic main restricted universe multiverse \n\
deb $SOURCES bionic-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list \
    # dns server
    && echo "nameserver 8.8.8.8" > /etc/resolv.conf

# reuses the cache
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # compile
        patch  make  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  cmake \
        # u-boot
        bison  flex \
        # kernel
        bc  libssl-dev  kmod \
        # initramfs
        cpio \
        # FIT(Flattened Image Tree)
        device-tree-compiler \
        # boot.img
        genext2fs \
        # rootfs
        binfmt-support  qemu-user-static \
        # local:en_US.UTF-8
        locales 

# locale
RUN locale-gen en_US.UTF-8

# setup build environment
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8' \
    TERM=screen \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH="arm64" \
    HOST="aarch64-linux-gnu" \
    BUILD="/root/build"

USER root

WORKDIR $BUILD

# kernel
#----------------------------------------------------------------------------------------------------------------#

ADD "packages/kernel-rockchip.tar.gz" "$BUILD/"
COPY "patches/kernel" "$BUILD/kernel-rockchip/patches/"
RUN set -x \
    && cd kernel-rockchip \
    # patch
    && for x in `ls patches`; do patch -p1 < patches/$x; done \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


RUN set -x \
    && cd kernel-rockchip \
    && export OUT="$BUILD/kmodules" \
    && make INSTALL_MOD_PATH=$OUT modules_install \
    && KREL=`make kernelrelease` \
    # useless
    && rm -rf "$OUT/lib/modules/$KREL/kernel/drivers/gpu/arm/mali400/" \
    && rm -rf "$OUT/lib/modules/$KREL/kernel/drivers/net/wireless/rockchip_wlan" \
    # strip
    && (cd $OUT && find . -name \*.ko | xargs aarch64-linux-gnu-strip --strip-unneeded)


# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "$BUILD/"
ADD "packages/rkbin.tar.gz" "$BUILD/"
RUN set -x \
    && cd u-boot \
    # make
    && make evb-rk3399_defconfig \
    # disable boot delay
    && sed -i "s:^CONFIG_BOOTDELAY.*:CONFIG_BOOTDELAY=0:" .config \
    && make -j$(nproc)


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "$BUILD/"
RUN set -x \
    && cd busybox \
    # make
    && make defconfig \
    # static link
    && sed -i "s:# CONFIG_STATIC is not set:CONFIG_STATIC=y:" .config \
    && make -j$(nproc) \
\
    && export OUT="$BUILD/initramfs" \
    && make CONFIG_PREFIX=$OUT install


# qemu
#----------------------------------------------------------------------------------------------------------------#
RUN apt-get install -y libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev python parted
ADD "packages/qemu.tar.gz" "$BUILD/"
RUN set -x \
    && cd qemu \
    && ./configure --target-list=aarch64-softmmu \
    # make
    && make -j$(nproc)

ADD "packages/qemu-u-boot.tar.gz" "$BUILD/"
RUN set -x \
    # qemu u-boot
    && cd qemu-u-boot \
    # make
    && make qemu_arm64_defconfig \
    && sed -i "s:^CONFIG_ARCH_QEMU.*:CONFIG_ARCH_QEMU=y:" .config \
    && sed -i "s:^CONFIG_TARGET_QEMU_ARM_64BIT.*:CONFIG_TARGET_QEMU_ARM_64BIT=y:" .config \
    && sed -i "s:^CONFIG_BOOTDELAY.*:CONFIG_BOOTDELAY=0:" .config \
    && sed -i "s:^CONFIG_FIT.*:CONFIG_FIT=y:" .config \
    && make -j$(nproc)


# ubuntu bionic
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ubuntu-rootfs.tar.gz" "$BUILD/rootfs"


# rockchip rootfs
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rk-rootfs-build.tar.gz" "$BUILD/"


# here we go
#----------------------------------------------------------------------------------------------------------------#

ENV DISTRO=/root/distro \
    QEMU=${BUILD}/qemu

WORKDIR /root/scripts
