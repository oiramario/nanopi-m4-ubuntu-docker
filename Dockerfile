# configure
#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.2.2" \
      email="oiramario@gmail.com"

# apt sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirror.tuna.tsinghua.edu.cn/ubuntu/" \
    && echo "\
deb ${SOURCES} bionic main restricted universe multiverse \n\
deb ${SOURCES} bionic-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list \
    # dns server
    && echo "nameserver 114.114.114.114" > /etc/resolv.conf

# reuses the cache
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # compile
        patch  make  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  pkg-config  cmake \
        # u-boot
        bison  flex \
        # kernel
        bc  libssl-dev  kmod \
        # libdrm
        autoconf  xutils-dev  libtool  libpciaccess-dev \
        # initramfs
        cpio \
        # FIT(Flattened Image Tree)
        device-tree-compiler \
        # boot.img
        genext2fs \
        # rootfs
        binfmt-support  qemu-user-static \
        # local:en_US.UTF-8
        locales \
    && locale-gen en_US.UTF-8


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

WORKDIR ${BUILD}

# kernel
#----------------------------------------------------------------------------------------------------------------#

ADD "packages/kernel.tar.gz" "${BUILD}/"
COPY "patches/kernel" "${BUILD}/kernel/patches/"
RUN set -x \
    && cd kernel \
    # patch
    && for x in `ls patches`; do patch -p1 < patches/$x; done \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


RUN set -x \
    && cd kernel \
    && export OUT="${BUILD}/kmodules" \
    && make INSTALL_MOD_PATH=${OUT} modules_install \
    && KREL=`make kernelrelease` \
    # useless
    && rm -rf "${OUT}/lib/modules/$KREL/kernel/drivers/gpu/arm/mali400/" \
    && rm -rf "${OUT}/lib/modules/$KREL/kernel/drivers/net/wireless/rockchip_wlan" \
    # strip
    && (cd ${OUT} \
    # remove build and source links
    && find . -name build | xargs rm -rf \
    && find . -name source | xargs rm -rf \
    # strip unneeded
    && find . -name \*.ko | xargs aarch64-linux-gnu-strip --strip-unneeded)


# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "${BUILD}/"
RUN set -x \
    && cd u-boot \
    # make
    && make rk3399_defconfig \
    && make -j$(nproc)


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "${BUILD}/"
COPY "patches/busybox" "${BUILD}/busybox/patches/"
RUN set -x \
    && cd busybox \
    # patch
    && for x in `ls patches`; do patch -p1 < patches/$x; done \
    # make
    && make defconfig \
    && make -j$(nproc) \
\
    && export OUT="${BUILD}/initramfs" \
    && make CONFIG_PREFIX=${OUT} install


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" "${BUILD}/"
ADD "packages/rk-rootfs-build.tar.gz" "${BUILD}/"


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS=${BUILD}/rootfs
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"


# cmake toolchain
#----------------------------------------------------------------------------------------------------------------#
COPY "toolchain.cmake" "${BUILD}/"


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" "${BUILD}/"
RUN set -x \
   && cd libmali \
   && cmake -DCMAKE_INSTALL_PREFIX:PATH="${ROOTFS}/usr/local" \
            -DTARGET_SOC=rk3399 -DDP_FEATURE=gbm . \
   && make install


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libdrm \
    && ./autogen.sh --prefix="${ROOTFS}/usr/local" --host="${HOST}" \
                    --disable-intel --disable-vmwgfx --disable-radeon \
                    --disable-amdgpu --disable-nouveau --disable-freedreno \
                    --disable-vc4 --enable-rockchip-experimental-api \
    && make -j$(nproc) \
    && make install


# gbm-drm-gles-cube
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ogles-cube.tar.gz" "${BUILD}/"
RUN set -x \
    && cd ogles-cube \
    && PKG_CONFIG_PATH="${ROOTFS}/usr/local/lib/pkgconfig" LDFLAGS="-L${ROOTFS}/usr/local/lib" \
       cmake -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
    && make -j$(nproc) \
    && aarch64-linux-gnu-strip --strip-unneeded ./gbm-drm-gles-cube \
    && cp ./gbm-drm-gles-cube "${ROOTFS}/usr/local/bin/"

# here we go
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO=/root/distro

WORKDIR /root/scripts
