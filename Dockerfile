#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.1" \
      email="oiramario@gmail.com"

# root
USER root

# cn sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirrors.163.com/ubuntu/" \
    && echo "\
deb $SOURCES bionic main restricted universe multiverse \n\
deb $SOURCES bionic-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list \
    # dns server
    && echo "nameserver 223.5.5.5" > /etc/resolv.conf \
    && echo "nameserver 223.6.6.6" >> /etc/resolv.conf \
    # reuses the cache
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
       apt-get install -y \
                     # compile
                    gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  make  patch \
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
                    # mali librealsense2
                    cmake

# setup build environment
ENV CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH="arm64" \
    HOST="aarch64-linux-gnu" \
    BUILD="/tmp" \
    DISTRO="/root"

WORKDIR "$BUILD"

#----------------------------------------------------------------------------------------------------------------#

# kernel
ADD "packages/kernel-rockchip.tar.gz" "$BUILD/"
COPY "patch/" "$BUILD/patch/"
RUN set -x \
    && cd kernel-rockchip \
    # patch
    && export REALSENSE_PATCH="../patch/kernel/realsense" \
    && for x in `ls $REALSENSE_PATCH`; do patch -p1 < $REALSENSE_PATCH/$x; done \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)

# u-boot
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
ADD "packages/busybox.tar.gz" "$BUILD/"
RUN set -x \
    && cd busybox \
    # make
    && make defconfig \
    # static link
    && sed -i "s:# CONFIG_STATIC is not set:CONFIG_STATIC=y:" .config \
    && make -j$(nproc)

#----------------------------------------------------------------------------------------------------------------#

ENV ROOTFS="$DISTRO/rootfs"
RUN mkdir -p $ROOTFS

# uboot
RUN set -x \
    && cd rkbin \
    && export PATH_FIXUP="--replace tools/rk_tools/ ./" \
\
    # boot loader
    && tools/boot_merger $PATH_FIXUP RKBOOT/RK3399MINIALL.ini \
\
    # idbloader.img
    && ../u-boot/tools/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img \
    && cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img \
\
    # uboot.img
    && tools/loaderimage --pack --uboot ../u-boot/u-boot.bin uboot.img 0x00200000 \
\
    # trust.img
    && tools/trust_merger $PATH_FIXUP RKTRUST/RK3399TRUST.ini \
\
    # copy content
    && cp idbloader.img uboot.img trust.img "$DISTRO/" \
    && cp rk3399_loader_*.bin "$DISTRO/MiniLoaderAll.bin"


# kernel modules
RUN set -x \
    && cd kernel-rockchip \
    && make INSTALL_MOD_PATH=$ROOTFS modules_install \
    && KREL=`make kernelrelease` \
    && rm -rf "$ROOTFS/lib/modules/$KREL/kernel/drivers/gpu/arm/mali400/" \
    && rm -rf "$ROOTFS/lib/modules/$KREL/kernel/drivers/net/wireless/rockchip_wlan" \
    && (cd $ROOTFS && find . -name \*.ko | xargs aarch64-linux-gnu-strip --strip-unneeded) \
\
    # modules: bt, wifi, audio
    && mkdir -p $ROOTFS/system/lib/modules/ \
    && cd "$BUILD/kernel-rockchip/drivers/net/wireless/rockchip_wlan" \
    && find . -name "*.ko" | xargs -n1 -i cp {} "$ROOTFS/system/lib/modules/"


# boot
ADD "packages/rk-rootfs-build.tar.gz" "$BUILD/"
COPY "boot/" "$BUILD/boot/"
RUN set -x \
    && export BOOT="$BUILD/boot" \
    && cd "$BUILD/kernel-rockchip/arch/arm64/boot" \
    # kernel
    && cp ./Image.gz "$BOOT/kernel.gz" \
    # dtb
    && cp ./dts/rockchip/rk3399-nanopi4-rev0*.dtb "$BOOT/" \
\
    # initramfs
    && export INITRAMFS="$BOOT/initramfs" \
    && cd "$BUILD/busybox" \
    && make CONFIG_PREFIX="$INITRAMFS" install \
\
    # firmware
    && mkdir -p $INITRAMFS/lib/firmware \
    && cd $BUILD/rk-rootfs-build/overlay-firmware/lib/firmware \
    && cp -rf rockchip $INITRAMFS/lib/firmware/ \
\
    # cpio.gz
    && cd "$INITRAMFS" \
    && rm linuxrc \
    && find . | cpio -o -H newc | gzip > "$BOOT/ramdisk.cpio.gz" \
\
    # FIT
    && mkdir -p $BOOT/image \
    && cd $BUILD/u-boot/tools \
    && ./mkimage -C none -A arm64 -T script -d $BOOT/boot.cmd $BOOT/image/boot.scr \
    && ./mkimage -f $BOOT/rk3399-fit.its $BOOT/image/fit.itb \
\
    # make image
    && export BOOT_IMG="$DISTRO/boot.img" \
    && genext2fs -b 65536 -d $BOOT/image $BOOT_IMG \
    && e2fsck -p -f $BOOT_IMG \
    && resize2fs -M $BOOT_IMG

#----------------------------------------------------------------------------------------------------------------#

# libmali
#ADD "packages/libmali.tar.gz" "$BUILD/"
#RUN set -x \
#    && cd libmali \
#    && mv include/midgard/arm/winsys_dummy include/midgard/arm/winsys_x11 \
#    && cmake -DCMAKE_INSTALL_PREFIX:PATH="${ROOTFS}/usr" \
#             -DTARGET_SOC=rk3399 -DDP_FEATURE=x11 . \
#    && make install


# librealsense
#RUN apt-get install -y sudo
#COPY "toolchain.cmake" "$BUILD/"
#ADD "packages/librealsense.tar.gz" "${BUILD}/"
#RUN set -x \
#    && cd librealsense \
#    && cp config/99-realsense-libusb.rules "${ROOTFS}/etc/udev/rules.d/" \
#    && ./scripts/patch-realsense-ubuntu-lts.sh \
#    && PKG_CONFIG_PATH="${ROOTFS}/usr/lib/pkgconfig" LDFLAGS="-L${ROOTFS}/usr/lib" \
#       cmake -DCMAKE_INSTALL_PREFIX:PATH="${ROOTFS}/usr" \
#             -DCMAKE_BUILD_TYPE=Release \
#             -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
#             -DBUILD_WITH_TM2=false -DBUILD_GRAPHICAL_EXAMPLES=false \
#             -DBUILD_EXAMPLES=false -DHWM_OVER_XU=false \
#             -DBUILD_WITH_STATIC_CRT=false . \
#    && make -j$(nproc) \
#    && make install


# gbm-drm-gles-cube
#ADD "packages/gbm-drm-gles-cube.tar.gz" "${BUILD}/"
#COPY "packages/src/gbm-drm-gles-cube" "${BUILD}/gbm-drm-gles-cube/"
#RUN set -x \
#    && cd gbm-drm-gles-cube \
#    && PKG_CONFIG_PATH="${ROOTFS}/usr/lib/pkgconfig" LDFLAGS="-L${ROOTFS}/usr/lib" \
#       cmake -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
#    && make -j$(nproc)


#----------------------------------------------------------------------------------------------------------------#

# clean
RUN set -x \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get -y autoremove \
    && apt-get clean

#    && cd "${ROOTFS}" \
#    && rm -rf include usr/include \
#    && rm -rf lib/pkgconfig lib/cmake lib/*.a lib/*.la \
#              usr/lib/pkgconfig usr/lib/cmake usr/lib/*.a usr/lib/*.la

RUN cd "$DISTRO" \
    && tar czf /boot.tar *

#----------------------------------------------------------------------------------------------------------------#