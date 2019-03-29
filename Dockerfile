#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.1" \
      email="oiramario@gmail.com"

# root
USER root

# silent installation for apt-get
ENV DEBIAN_FRONTEND noninteractive

# cn sources
RUN SOURCES="http://mirrors.aliyun.com/ubuntu/" \
    && cat << EOF > /etc/apt/sources.list \
    && echo "\
deb $SOURCES bionic main restricted universe multiverse \n\
deb $SOURCES bionic-security main restricted universe multiverse \n\
deb $SOURCES bionic-updates main restricted universe multiverse \n\
deb $SOURCES bionic-proposed main restricted universe multiverse \n\
deb $SOURCES bionic-backports main restricted universe multiverse" > /etc/apt/sources.list \
    # reuses the cache
    && apt-get update \
    && apt-get install -y apt-utils \
                    # compile
                    gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  make  patch \
                    # u-boot
                    bison  flex \
                    # kernel
                    bc  libssl-dev \
                    # libdrm
                    autoconf xutils-dev libtool pkg-config libpciaccess-dev \
                    # mali librealsense2
                    cmake \
                    # eudev
                    gperf

# setup build environment
ENV CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH="arm64" \
    HOST="aarch64-linux-gnu" \
    BUILD="/root/build" \
    REDIST="/root/redist"

ENV BOOT="$REDIST/boot" \
    ROOTFS="$REDIST/rootfs"
RUN mkdir -p "$BUILD"  "$REDIST"  "$BOOT"  "$ROOTFS"

WORKDIR "$BUILD"

#----------------------------------------------------------------------------------------------------------------#

# kernel
ADD "packages/kernel.tar.xz" "$BUILD/"
COPY "patch/" "$BUILD/patch/"
RUN set -x \
    && cd kernel \
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
    && make evb-rk3399_defconfig \
    # disable boot delay
    && sed -i "s:^CONFIG_BOOTDELAY.*:CONFIG_BOOTDELAY=0:" .config \
    && make -j$(nproc)


# busybox
ADD "packages/busybox.tar.xz" "$BUILD/"
RUN set -x \
    && cd busybox \
    && make defconfig \
    && make -j$(nproc)


ENV PREFIX="${ROOTFS}/usr/local"
ENV PKG_CONFIG_PATH "${PREFIX}/lib/pkgconfig"


# libdrm
ADD "packages/libdrm.tar.xz" "${BUILD}"
RUN set -x \
    && cd libdrm \
    && ./autogen.sh --prefix="${PREFIX}" --host="${HOST}" \
                    --disable-intel --disable-vmwgfx --disable-radeon \
                    --disable-amdgpu --disable-nouveau --disable-freedreno \
                    --disable-vc4 --enable-rockchip-experimental-api \
    && make -j$(nproc) \
    && make install


# libmali
ADD "packages/libmali.tar.xz" "${BUILD}"
RUN set -x \
    && cd "libmali" \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
             -DTARGET_SOC=rk3399 -DDP_FEATURE=gbm . \
    && make install

#----------------------------------------------------------------------------------------------------------------#

# boot loader images
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
    && cp idbloader.img uboot.img trust.img "$REDIST/" \
    && cp rk3399_loader_*.bin "$REDIST/MiniLoaderAll.bin" \
\
    # copy flash tool
    && cp tools/rkdeveloptool "$REDIST/"


# GPT partition table
COPY "boot/parameter" "$REDIST/"


# rkdeveloptool rockusb.rules
COPY "boot/99-rk-rockusb.rules" "$REDIST/"


# boot
COPY "boot/extlinux.conf" "$BOOT/extlinux/"
RUN set -x \
    && cd kernel \
    && cp arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev01.dtb \
          arch/arm64/boot/Image \
          "$BOOT/"


# rootfs
COPY "rootfs/" "$ROOTFS/"
RUN set -x \
    # busybox
    && cd busybox \
    && make CONFIG_PREFIX="$ROOTFS" install \
\
    # runtime
    && cd "$ROOTFS" \
    && cp -rf /usr/aarch64-linux-gnu/lib/* lib/ \
    && rm -f lib/*.a lib/*.o

ADD "packages/rk-rootfs-build.tar.xz" "$BUILD/"
RUN set -x \
    # bt, wifi, audio
    && find "$BUILD/kernel/drivers/net/wireless/rockchip_wlan/" \
            -name "*.ko" | xargs -n1 -i cp {} "$ROOTFS/system/lib/modules" \
    && cp -rf $BUILD/rk-rootfs-build/overlay-firmware/* $ROOTFS/ \
    && cd "$ROOTFS/usr/bin/" \
    && mv brcm_patchram_plus1_64 brcm_patchram_plus1 \
    && rm brcm_patchram_plus1_32 \
    && mv rk_wifi_init_64 rk_wifi_init \
    && rm rk_wifi_init_32

#----------------------------------------------------------------------------------------------------------------#

RUN cd "$REDIST" \
    && tar czf /redist.tar *

#----------------------------------------------------------------------------------------------------------------#