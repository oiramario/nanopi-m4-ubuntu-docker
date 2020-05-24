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
        # gdb
        texinfo \
        # libdrm
        autoconf  xutils-dev  libtool  libpciaccess-dev \
        # eudev
        gperf \
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


# RUN set -x \
#     && cd kernel \
#     && export OUT="${BUILD}/kmodules" \
#     && make INSTALL_MOD_PATH=${OUT} modules_install \
#     && KREL=`make kernelrelease` \
#     # useless
#     && rm -rf "${OUT}/lib/modules/$KREL/kernel/drivers/gpu/arm/mali400/" \
#     && rm -rf "${OUT}/lib/modules/$KREL/kernel/drivers/net/wireless/rockchip_wlan" \
#     # strip
#     && cd ${OUT} \
#     # remove build and source links
#     && find . -name build | xargs rm -rf \
#     && find . -name source | xargs rm -rf \
#     # strip unneeded
#     && find . -name \*.ko | xargs aarch64-linux-gnu-strip --strip-unneeded


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
    && make CONFIG_PREFIX=${BUILD}/initramfs install


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" "${BUILD}/"
ADD "packages/rk-rootfs-build.tar.gz" "${BUILD}/"
RUN set -x \
    && cd rk-rootfs-build \
    # rockchip firmware
    && cp -rf overlay-firmware/* ${ROOTFS}/ \
    # choose 64bits
    && mv -f ${ROOTFS}/usr/bin/brcm_patchram_plus1_64 ${ROOTFS}/usr/bin/brcm_patchram_plus1 \
    && mv -f ${ROOTFS}/usr/bin/rk_wifi_init_64 ${ROOTFS}/usr/bin/rk_wifi_init \
    && rm -f ${ROOTFS}/usr/bin/brcm_patchram_plus1_32 ${ROOTFS}/usr/bin/rk_wifi_init_32 \
    # bt, wifi, audio firmware
    && mkdir -p ${ROOTFS}/system/lib/modules \
    && find ${BUILD}/kernel/drivers/net/wireless/rockchip_wlan -name "*.ko" | \
        xargs -n1 -i cp {} ${ROOTFS}/system/lib/modules/


# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX=/opt/devkit
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV CFLAGS="-I${PREFIX}/include"
ENV LDFLAGS="-L${PREFIX}/lib"
COPY "toolchain.cmake" "${BUILD}/"


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libmali \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DTARGET_SOC=rk3399 \
                -DDP_FEATURE=gbm \
                . \
    && make install


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libdrm \
    && ./autogen.sh --prefix=${PREFIX} --host=${HOST} \
                    --disable-intel \
                    --disable-vmwgfx \
                    --disable-radeon \
                    --disable-amdgpu \
                    --disable-nouveau \
                    --disable-freedreno \
                    --disable-vc4 \
                    --enable-rockchip-experimental-api \
    && make -j$(nproc) \
    && make install


# eudev
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/eudev.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd eudev \
    && autoreconf -vfi \
    && ./configure  --prefix=${PREFIX} --host=${HOST} \
                    --disable-blkid \
                    --disable-kmod \
    && make -j$(nproc) \
    && make install


# libusb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libusb.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd libusb \
    && autoreconf -vfi \
    && ./configure --prefix=${PREFIX} --host=${HOST} \
    && make -j$(nproc) \
    && make install


# librealsense
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librealsense.tar.gz" "${BUILD}/"
RUN set -x \
    && cd librealsense \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_TOOLCHAIN_FILE=${BUILD}/toolchain.cmake \
                -DBUILD_WITH_TM2=false \
                -DBUILD_GRAPHICAL_EXAMPLES=false \
                -DBUILD_EXAMPLES=false \
                -DBUILD_WITH_STATIC_CRT=false \
                -DFORCE_RSUSB_BACKEND=true \
                -DIMPORT_DEPTH_CAM_FW=false \
                . \
    && make -j$(nproc) \
    && make install


RUN set -x \
    && mkdir -p ${ROOTFS}/etc/udev/rules.d/ \
    && cp librealsense/config/99-realsense-libusb.rules ${ROOTFS}/etc/udev/rules.d/


# gdb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gdb.tar.gz" "${BUILD}/"
RUN set -x \
    && cd gdb \
    && mkdir build && cd build \
    && ../configure --host=x86_64-linux-gnu --target=${HOST} \
    && make -j$(nproc)

RUN set -x \
    && cd gdb/gdb/gdbserver \
    && ./configure --host=${HOST} --target=${HOST} \
    && make -j$(nproc)

RUN set -x \
    # gdb
    && cp gdb/build/gdb/gdb ${PREFIX}/  \
    # gdbserver
    && cp gdb/gdb/gdbserver/gdbserver ${ROOTFS}/usr/local/bin/


# gbm-drm-gles-cube
#----------------------------------------------------------------------------------------------------------------#
# ADD "packages/ogles-cube.tar.gz" "${BUILD}/"
# RUN set -x \
#     && cd ogles-cube \
#     && cmake -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
#     && make -j$(nproc) \
#     && cp ./gbm-drm-gles-cube "${ROOTFS}/opt/"


# clean useless
#----------------------------------------------------------------------------------------------------------------#
# RUN cd "${PREFIX}" \
#     && rm -rf include lib/pkgconfig lib/cmake lib/udev \
#     && rm -f lib/*.a lib/*.la \
#     && find lib -name \*.so | xargs aarch64-linux-gnu-strip --strip-unneeded \
#     && aarch64-linux-gnu-strip --strip-unneeded ./bin/*


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO=/root/distro
ENV DEVKIT=/root/devkit

WORKDIR /root/scripts
