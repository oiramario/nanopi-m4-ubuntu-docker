FROM ubuntu:bionic
LABEL author="oiramario"
LABEL version="0.1"
LABEL email="oiramario@gmail.com"

# root
RUN echo "root:root" | chpasswd
USER root

#----------------------------------------------------------------------------------------------------------------#

# cn sources
RUN SOURCES="http://mirrors.163.com/ubuntu/" \
    && cat << EOF > /etc/apt/sources.list \
    && echo "\
deb ${SOURCES} bionic main restricted universe multiverse \n\
deb ${SOURCES} bionic-security main restricted universe multiverse \n\
deb ${SOURCES} bionic-updates main restricted universe multiverse \n\
deb ${SOURCES} bionic-proposed main restricted universe multiverse \n\
deb ${SOURCES} bionic-backports main restricted universe multiverse" > /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y \
                    gcc g++ \
                    gcc-8-aarch64-linux-gnu g++-8-aarch64-linux-gnu \
                    make

# setup build environment
ENV CROSS_COMPILE "aarch64-linux-gnu-"
ENV ARCH arm64

RUN cd /usr/bin \
    && ln -s aarch64-linux-gnu-gcc-8 aarch64-linux-gnu-gcc \
    && ln -s aarch64-linux-gnu-g++-8 aarch64-linux-gnu-g++

ENV BUILD "/opt/build"
WORKDIR ${BUILD}

#----------------------------------------------------------------------------------------------------------------#

RUN apt-get install -y \
                    # kernel
                    patch bc libssl-dev liblz4-tool

ENV BOOT "/opt/boot"
RUN mkdir -p "${BOOT}"


# build kernel
ENV KERNEL_VERSION 4.4
ADD "./packages/boot/kernel-${KERNEL_VERSION}.tar.xz" "${BUILD}"
# git clone https://github.com/friendlyarm/kernel-rockchip.git --depth 1 -b nanopi4-linux-v4.4.y kernel
# git clone https://github.com/rockchip-linux/kernel.git --depth 1 -b stable-4.4-rk3399-linux kernel
COPY "./packages/boot/modify_urb_number_and_uvc_packet.patch" "${BUILD}/kernel"
COPY "./packages/boot/rk3399-irqchip-xhci-irq-142-to-all-cpu.patch" "${BUILD}/kernel"
RUN set -x \
    && cd kernel \
    && patch -p1 < modify_urb_number_and_uvc_packet.patch \
    && patch -p1 < rk3399-irqchip-xhci-irq-142-to-all-cpu.patch \
    && make nanopi4_linux_defconfig \
    && make nanopi4-images -j$(nproc) \
    && cp kernel.img resource.img "${BOOT}"


# build u-boot
ENV UBOOT_VERSION stable-4.4-rk3399-linux
ADD "./packages/boot/u-boot-${UBOOT_VERSION}.tar.xz" "${BUILD}"
# git clone https://github.com/rockchip-linux/u-boot.git --depth 1 -b stable-4.4-rk3399-linux u-boot
ADD "./packages/boot/rkbin.tar.xz" "${BUILD}"
# git clone https://github.com/rockchip-linux/rkbin.git --depth 1 rkbin
RUN set -x \
    && cd u-boot \
    && ./make.sh rk3399 \
    && cp uboot.img trust.img rk3399_loader_*.bin "${BOOT}" \
    && cd ../rkbin/tools \
    && cp resource_tool rkdeveloptool parameter_gpt.txt "${BOOT}"

#----------------------------------------------------------------------------------------------------------------#

RUN apt-get install -y \
                    # libdrm
                    autoconf xutils-dev libtool pkg-config libpciaccess-dev \
                    # mali librealsense2
                    cmake \
                    # eudev
                    gperf

ENV ROOTFS "${BOOT}/rootfs"
RUN mkdir -p "${ROOTFS}" \
    && cd "${ROOTFS}" \
    && mkdir dev etc lib usr var proc tmp home root mnt sys

ENV HOST "aarch64-linux-gnu"
ENV PREFIX "${ROOTFS}/usr/local"
ENV PKG_CONFIG_PATH "${PREFIX}/lib/pkgconfig"

RUN echo "\
SET(CMAKE_SYSTEM_NAME Linux)\n\
SET(CMAKE_SYSTEM_PROCESSOR aarch64)\n\
\n\
SET(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)\n\
SET(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)\n\
\n\
SET(CMAKE_FIND_ROOT_PATH aarch64-linux-gnu)\n\
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n\
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)\n\
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)" > "${BUILD}/toolchain.cmake"


# build libdrm
ENV LIBDRM_VERSION 2.4.91
ADD "./packages/rootfs/libdrm-${LIBDRM_VERSION}.tar.xz" "${BUILD}"
# git clone https://github.com/numbqq/libdrm-rockchip.git --depth 1 -b rockchip-2.4.91 libdrm-2.4.91
RUN set -x \
    && cd "libdrm-${LIBDRM_VERSION}" \
    && ./autogen.sh --prefix="${PREFIX}" --host="${HOST}" \
                    --disable-intel --disable-vmwgfx --disable-radeon \
                    --disable-amdgpu --disable-nouveau --disable-freedreno \
                    --disable-vc4 --enable-rockchip-experimental-api \
    && make -j$(nproc) && make install


# build mali
ENV MALI_VERSION 14.0
ADD "./packages/rootfs/mali-${MALI_VERSION}.tar.xz" "${BUILD}"
# git clone https://github.com/rockchip-linux/libmali.git --depth 1 -b rockchip
RUN set -x \
    && cd "mali-${MALI_VERSION}" \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" . \
    && make install


# build eudev
ENV EUDEV_VERSION 3.2.7
ADD "./packages/rootfs/eudev-${EUDEV_VERSION}.tar.xz" "${BUILD}"
# wget https://github.com/gentoo/eudev/archive/v3.2.7.tar.gz
RUN set -x \ 
    && cd "eudev-${EUDEV_VERSION}" \
    && autoreconf -vfi \
    && ./configure --prefix="${PREFIX}" --host="${HOST}" --disable-blkid --disable-kmod \
    && make -j$(nproc) && make install


# build libusb
ENV LIBUSB_VERSION 1.0.22
ADD "./packages/rootfs/libusb-${LIBUSB_VERSION}.tar.xz" "${BUILD}"
# wget https://github.com/libusb/libusb/archive/v1.0.22.tar.gz
RUN set -x \ 
    && cd "libusb-${LIBUSB_VERSION}" \
    && autoreconf -vfi \
    && ./configure --prefix="${PREFIX}" --host="${HOST}" \
    CFLAGS="-I${PREFIX}/include" LDFLAGS="-L${PREFIX}/lib" \
    && make -j$(nproc) && make install


# build librealsense
ENV LIBREALSENSE_VERSION 2.18.1
ADD "./packages/rootfs/librealsense-${LIBREALSENSE_VERSION}.tar.xz" "${BUILD}"
# wget https://github.com/IntelRealSense/librealsense/archive/v2.18.1.tar.gz
RUN set -x \
    && cd "librealsense-${LIBREALSENSE_VERSION}" \
    && LDFLAGS="-L${PREFIX}/lib" \
    cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
          -DBUILD_WITH_TM2=false -DBUILD_GRAPHICAL_EXAMPLES=false \
          -DBUILD_EXAMPLES=false -DHWM_OVER_XU=false \
          -DBUILD_WITH_STATIC_CRT=false . \
    && make -j$(nproc) && make install


# build busybox
ENV BUSYBOX_VERSION 1.30.1
ADD "./packages/rootfs/busybox-${BUSYBOX_VERSION}.tar.xz" "${BUILD}"
# wget https://github.com/mirror/busybox/archive/1_30_1.tar.gz
RUN set -x \
    && cd "busybox-${BUSYBOX_VERSION}" \
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${ROOTFS}" install \
    && cp -r examples/bootfloppy/etc/* "${ROOTFS}/etc"


# build overlay-firmware
ENV OVERLAY_FIRMWARE_VERSION 2018.10.18
ADD "./packages/rootfs/overlay-firmware-${OVERLAY_FIRMWARE_VERSION}.tar.xz" "${BUILD}"
# git clone https://github.com/nishantpoorswani/nanopi-m4-bin --depth 1
RUN set -x \
    && cd "overlay-firmware-${OVERLAY_FIRMWARE_VERSION}" \
    # some configs
    && cp usr/bin/brcm_patchram_plus1_64 "${ROOTFS}/usr/bin/brcm_patchram_plus1" \
    && cp usr/bin/rk_wifi_init_64 "${ROOTFS}/usr/bin/rk_wifi_init" \
    # bt,wifi,audio firmware
    && mkdir -p "${ROOTFS}/system/lib/modules" \
    && find "${BUILD}/kernel/drivers/net/wireless/rockchip_wlan/*"  -name "*.ko" | \
            xargs -n1 -i cp {} "${ROOTFS}/system/lib/modules" \
    && cp -a * "${ROOTFS}"


# clean rootfs
RUN cd "${PREFIX}" \
    && rm -rf include \
    && rm -rf lib/pkgconfig lib/cmake \
    && rm -f lib/*.a

RUN cd "${BOOT}" \
    && tar cf /boot.tar *
