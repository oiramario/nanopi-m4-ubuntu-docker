#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.1" \
      email="oiramario@gmail.com"

# root
USER root

# cn sources
RUN SOURCES="http://mirrors.aliyun.com/ubuntu/" \
    && cat << EOF > /etc/apt/sources.list \
    && echo "\
deb $SOURCES bionic main restricted universe multiverse \n\
deb $SOURCES bionic-security main restricted universe multiverse \n\
deb $SOURCES bionic-updates main restricted universe multiverse \n\
deb $SOURCES bionic-proposed main restricted universe multiverse \n\
deb $SOURCES bionic-backports main restricted universe multiverse\
" > /etc/apt/sources.list \
    # silent installation for apt-get
    && DEBIAN_FRONTEND=noninteractive \
    # reuses the cache
    && apt-get update \
    && apt-get install -y --no-install-recommends install \
                     # compile
                    gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  make  patch \
                    # u-boot
                    bison  flex \
                    # kernel
                    bc  libssl-dev \
                    # initrd
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
ADD "packages/kernel-rockchip.tar.xz" "$BUILD/"
COPY "patch/" "$BUILD/patch/"
RUN set -x \
    && cd kernel-rockchip \
\
    # patch
    && export REALSENSE_PATCH=../patch/kernel/realsense \
    && for i in `ls $REALSENSE_PATCH`; do patch -p1 < $REALSENSE_PATCH/$i; done \
\
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


# u-boot
ADD "packages/u-boot.tar.xz" "$BUILD/"
ADD "packages/rkbin.tar.xz" "$BUILD/"
RUN set -x \
    && cd u-boot \
\
    && make evb-rk3399_defconfig \
    # disable boot delay
    && sed -i "s:^CONFIG_BOOTDELAY.*:CONFIG_BOOTDELAY=0:" .config \
\
    && make -j$(nproc)


# busybox
ADD "packages/busybox.tar.xz" "$BUILD/"
RUN set -x \
    && cd busybox \
\
    && make defconfig \
    # static link
    && sed -i "s:# CONFIG_STATIC is not set:CONFIG_STATIC=y:" .config \
\
    && make -j$(nproc) \
    && make install

#----------------------------------------------------------------------------------------------------------------#

ENV ROOTFS="$DISTRO/rootfs"

# rootfs
ADD "packages/rk-rootfs-build.tar.xz" "$BUILD/"
ADD "packages/rootfs.tar.xz" "$DISTRO/"
#COPY "rootfs/" "$ROOTFS/"
RUN set -x \
    # modules: bt, wifi, audio
    && cd "$BUILD/kernel-rockchip/drivers/net/wireless/rockchip_wlan" \
    && mkdir -p "$ROOTFS/lib/modules" \
    && find . -name "*.ko" | xargs -n1 -i cp {} "$ROOTFS/lib/modules/" \
\
    # firmware
    && cp -R $BUILD/rk-rootfs-build/overlay-firmware/* $ROOTFS/ \
    && cd "$ROOTFS/usr/bin/" \
    && mv -f brcm_patchram_plus1_64 brcm_patchram_plus1 \
    && mv -f rk_wifi_init_64 rk_wifi_init \
    && rm -f brcm_patchram_plus1_32 rk_wifi_init_32 

# libmali
#ADD "packages/libmali.tar.xz" "${BUILD}/"
#RUN set -x \
#    && cd libmali \
#    && cmake -DCMAKE_INSTALL_PREFIX:PATH="${ROOTFS}/usr" \
#             -DTARGET_SOC=rk3399 -DDP_FEATURE=gbm . \
#    && make install


# eudev
#ADD "packages/eudev.tar.xz" "${BUILD}/"
#RUN set -x \ 
#    && cd eudev \
#    && autoreconf -vfi \
#    && ./configure --prefix="${ROOTFS}" --host="${HOST}" \
#                   --disable-blkid --disable-kmod \
#    && make -j$(nproc) \
#    && make install


# libusb
#ADD "packages/libusb.tar.xz" "${BUILD}/"
#RUN set -x \ 
#    && cd libusb \
#    && autoreconf -vfi \
#    && CFLAGS="-I${ROOTFS}/include" LDFLAGS="-L${ROOTFS}/lib" \
#       ./configure --prefix="${ROOTFS}/usr" --host="${HOST}" \
#    && make -j$(nproc) \
#    && make install


# librealsense
#RUN apt-get install -y sudo
#COPY "toolchain.cmake" "$BUILD/"
#ADD "packages/librealsense.tar.xz" "${BUILD}/"
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
#ADD "packages/gbm-drm-gles-cube.tar.xz" "${BUILD}/"
#COPY "packages/src/gbm-drm-gles-cube" "${BUILD}/gbm-drm-gles-cube/"
#RUN set -x \
#    && cd gbm-drm-gles-cube \
#    && PKG_CONFIG_PATH="${ROOTFS}/usr/lib/pkgconfig" LDFLAGS="-L${ROOTFS}/usr/lib" \
#       cmake -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
#    && make -j$(nproc)


#----------------------------------------------------------------------------------------------------------------#

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


# boot.img
ENV BOOT="$BUILD/boot"
COPY "boot/" "$BOOT/"
RUN set -x \
    && cd "$BUILD/kernel-rockchip/arch/arm64/boot" \
    # kernel
    && cp ./Image.gz "$BOOT/kernel.gz" \
    # dtb
    && cp ./dts/rockchip/rk3399-nanopi4-rev0*.dtb "$BOOT/" \
\
    # initramfs
    && cd "$BOOT/initramfs" \
    && cp -R $BUILD/busybox/_install/* . \
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
    && export BOOT_IMG=$DISTRO/boot.img \
    && genext2fs -b 32768 -B $((32*1024*1024/32768)) -d $BOOT/image -i 8192 -U $BOOT_IMG \
    && e2fsck -p -f $BOOT_IMG \
    && resize2fs -M $BOOT_IMG


#RUN set -x \
#    && cd gbm-drm-gles-cube \
#    && cp gbm-drm-gles-cube "$ROOTFS/usr/bin/"


#----------------------------------------------------------------------------------------------------------------#

# clean
RUN set -x \
    && apt -y autoremove \
    && apt clean

#    && cd "${ROOTFS}" \
#    && rm -rf include usr/include \
#    && rm -rf lib/pkgconfig lib/cmake lib/*.a lib/*.la \
#              usr/lib/pkgconfig usr/lib/cmake usr/lib/*.a usr/lib/*.la

RUN cd "$DISTRO" \
    && tar czf /distro.tar *

#----------------------------------------------------------------------------------------------------------------#