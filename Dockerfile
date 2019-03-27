#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.1" \
      email="oiramario@gmail.com"

# root
RUN echo "root:root" | chpasswd
USER root

#----------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------#

# cn sources
RUN SOURCES="http://mirrors.aliyun.com/ubuntu/" \
    && cat << EOF > /etc/apt/sources.list \
    && echo "\
deb ${SOURCES} bionic main restricted universe multiverse \n\
deb ${SOURCES} bionic-security main restricted universe multiverse \n\
deb ${SOURCES} bionic-updates main restricted universe multiverse \n\
deb ${SOURCES} bionic-proposed main restricted universe multiverse \n\
deb ${SOURCES} bionic-backports main restricted universe multiverse" > /etc/apt/sources.list \
    # reuses the cache
    && apt-get update \
    && apt-get install -y \
                    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
                    make \
                    patch

# setup build environment
ENV CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH=arm64

ENV BUILD "/root/build"
WORKDIR ${BUILD}

#----------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------#

RUN apt-get install -y \
                    # u-boot
                    bison flex \
                    # kernel
                    bc libssl-dev \
                    # boot.img
                    genext2fs

ENV RK3399 "/root/rk3399"
RUN mkdir -p ${RK3399}

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 --single-branch -b nanopi4-linux-v4.4.y https://github.com/friendlyarm/kernel-rockchip.git kernel
ADD "packages/kernel.tar.xz" "${BUILD}"

# patch
COPY "patch/" "${BUILD}/patch/"
RUN set -x \
    && cd kernel \
    # realsense
    && export REALSENSE_PATCH=../patch/kernel/realsense \
    && for i in `ls ${REALSENSE_PATCH}`; do patch -p1 < ${REALSENSE_PATCH}/$i; done 

# kernel
RUN set -x \
    && cd kernel \
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 --single-branch -b master https://github.com/u-boot/u-boot.git u-boot
ADD "packages/u-boot.tar.xz" "${BUILD}"

    # git clone --depth 1 --single-branch -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/rkbin.git rkbin
ADD "packages/rkbin.tar.xz" "${BUILD}"

# u-boot
RUN set -x \
    && cd u-boot \
    && make evb-rk3399_defconfig \
    && sed -i "s:^CONFIG_BOOTDELAY.*:CONFIG_BOOTDELAY=0:" .config \
    && make -j$(nproc)

#----------------------------------------------------------------------------------------------------------------#

ENV ROOTFS "${RK3399}/rootfs"
RUN mkdir -p ${ROOTFS}

    # http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz
ADD "packages/ubuntu-18.04.tar.xz" "${ROOTFS}"

RUN set -x \
    && cd "${ROOTFS}" 

#----------------------------------------------------------------------------------------------------------------#

# make images
RUN set -x \
    && cd rkbin \
    && export SYS_TEXT_BASE=0x00200000 \
    && export PATH_FIXUP="--replace tools/rk_tools/ ./" \
\
    # boot loader
    && tools/boot_merger ${PATH_FIXUP} RKBOOT/RK3399MINIALL.ini \
\
    # idbloader.img
    && ../u-boot/tools/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img \
    && cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img \
\
    # uboot.img
    && tools/loaderimage --pack --uboot ../u-boot/u-boot.bin uboot.img ${SYS_TEXT_BASE} \
\
    # trust.img
    && tools/trust_merger ${PATH_FIXUP} RKTRUST/RK3399TRUST.ini \
\
    # copy content
    && cp idbloader.img uboot.img trust.img "${RK3399}" \
    && cp rk3399_loader_*.bin "${RK3399}/MiniLoaderAll.bin" \
\
    # copy flash tool
    && cp tools/rkdeveloptool "${RK3399}"

# GPT parameter
COPY "boot/parameter" "${RK3399}"

# Rockusb rules
COPY "boot/99-rk-rockusb.rules" "${RK3399}"

#----------------------------------------------------------------------------------------------------------------#

ENV BOOT "${BUILD}/boot"
RUN mkdir -p "${BOOT}/extlinux"

# extlinux.conf
COPY "boot/extlinux.conf" "${BOOT}/extlinux"

# boot.img
RUN set -x \
    && cd kernel \
    && cp arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev01.dtb \
          arch/arm64/boot/Image \
          "${BOOT}/" \
\
    && genext2fs -b 32768 -B $((32*1024*1024/32768)) -d ${BOOT} -i 8192 -U ${RK3399}/boot.img \
    && e2fsck -p -f ${RK3399}/boot.img \
    && resize2fs -M ${RK3399}/boot.img

#----------------------------------------------------------------------------------------------------------------#

ADD "./packages/overlay-firmware.tar.xz" "${BUILD}"
# git clone https://github.com/nishantpoorswani/nanopi-m4-bin --depth 1
#RUN set -x \
#    && cd "overlay-firmware" \
    # bt,wifi,audio firmware
#    && mkdir -p "${ROOTFS}/system/lib/modules" \
#    && find "${BUILD}/kernel/drivers/net/wireless/rockchip_wlan/" -name "*.ko" | \
#            xargs -n1 -i cp {} "${ROOTFS}/system/lib/modules" \
#    && cp -a * "${ROOTFS}"

#----------------------------------------------------------------------------------------------------------------#

RUN cd "${RK3399}" \
    && tar cf /boot.tar *

#----------------------------------------------------------------------------------------------------------------#
