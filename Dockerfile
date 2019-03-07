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
RUN SOURCES="http://mirrors.163.com/ubuntu/" \
    && cat << EOF > /etc/apt/sources.list \
    && echo "\
deb ${SOURCES} bionic main restricted universe multiverse \n\
deb ${SOURCES} bionic-security main restricted universe multiverse \n\
deb ${SOURCES} bionic-updates main restricted universe multiverse \n\
deb ${SOURCES} bionic-proposed main restricted universe multiverse \n\
deb ${SOURCES} bionic-backports main restricted universe multiverse" > /etc/apt/sources.list \
    # reuses the cache
    && apt-get update

RUN apt-get install -y \
                    gcc \
                    gcc-8-aarch64-linux-gnu g++-8-aarch64-linux-gnu \
                    make \
                    patch \
                    git

# setup build environment
ENV CROSS_COMPILE "aarch64-linux-gnu-"
ENV ARCH arm64

RUN cd /usr/bin \
    && ln -s aarch64-linux-gnu-gcc-8 aarch64-linux-gnu-gcc \
    && ln -s aarch64-linux-gnu-g++-8 aarch64-linux-gnu-g++ \
    && ln -s aarch64-linux-gnu-cpp-8 aarch64-linux-gnu-cpp

ENV BUILD "/opt/build"
WORKDIR ${BUILD}

#----------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------#

RUN apt-get install -y \
                    # u-boot
                    bison flex \
                    # kernel
                    bc libssl-dev liblz4-tool python

ENV BOOT "/opt/boot"
RUN mkdir -p "${BOOT}"

# http://opensource.rock-chips.com/wiki_Boot_option
#+--------+----------------+----------+-------------+---------+
#| Boot   | Terminology #1 | Actual   | Rockchip    | Image   |
#| stage  |                | program  |  Image      | Location|
#| number |                | name     |   Name      | (sector)|
#+--------+----------------+----------+-------------+---------+
#| 1      |  Primary       | ROM code | BootRom     |         |
#|        |  Program       |          |             |         |
#|        |  Loader        |          |             |         |
#|        |                |          |             |         |
#| 2      |  Secondary     | U-Boot   |idbloader.img| 0x40    | pre-loader
#|        |  Program       | TPL/SPL  |             |         |
#|        |  Loader (SPL)  |          |             |         |
#|        |                |          |             |         |
#| 3      |  -             | U-Boot   | u-boot.itb  | 0x4000  | including u-boot and atf
#|        |                |          | uboot.img   |         | only used with miniloader
#|        |                |          |             |         |
#|        |                | ATF/TEE  | trust.img   | 0x6000  | only used with miniloader
#|        |                |          |             |         |
#| 4      |  -             | kernel   | boot.img    | 0x8000  |
#|        |                |          |             |         |
#| 5      |  -             | rootfs   | rootfs.img  | 0x40000 |
#+--------+----------------+----------+-------------+---------+

# GPT parameter
RUN echo "\
FIRMWARE_VER: 6.0.1\n\
MACHINE_MODEL: RK3399\n\
MACHINE_ID: 007\n\
MANUFACTURER: RK3399\n\
MAGIC: 0x5041524B\n\
ATAG: 0x00200800\n\
MACHINE: 3399\n\
CHECK_MASK: 0x80\n\
PWR_HLD: 0,0,A,0,1\n\
#KERNEL_IMG: 0x00280000\n\
#FDT_NAME: rk-kernel.dtb\n\
#RECOVER_KEY: 1,1,0,20,0\n\
CMDLINE: console=ttyFIQ0 root=/dev/mmcblk1p6 rw rootwait \
mtdparts=rk29xxnand:\
0x00001F40@0x00000040(idbloader),\
0x00000080@0x00001F80(reserved1),\
0x00002000@0x00002000(reserved2),\
0x00002000@0x00004000(uboot),\
0x00002000@0x00006000(trust),\
0x00038000@0x00008000(boot),\
-@0x00040000(rootfs)" > "${BOOT}/parameter"

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 https://github.com/rockchip-linux/u-boot.git u-boot
ADD "./packages/boot/u-boot.tar.xz" "${BUILD}"
    # git clone --depth 1 https://github.com/rockchip-linux/rkbin.git rkbin
ADD "packages/boot/rkbin.tar.xz" "${BUILD}"

# u-boot
RUN set -x \
    && cd u-boot \
    && make rk3399_defconfig \
    && make -j$(nproc)

# make images
RUN set -x \
    && cd rkbin \
    && export SYS_TEXT_BASE=0x00200000 \
    && export IMG_SIZE="--size 1024 2" \
    && export PATH_FIXUP="--replace tools/rk_tools/ ./" \
\
    # loader
    && tools/boot_merger ${PATH_FIXUP} RKBOOT/RK3399MINIALL.ini \
\
    # idbloader.img
    && ../u-boot/tools/mkimage -T rksd -n rk3399 -d $(find bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img \
    && cat $(find bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img \
\
    # uboot.img
    && tools/loaderimage --pack --uboot ../u-boot/u-boot-dtb.bin uboot.img ${SYS_TEXT_BASE} ${IMG_SIZE} \
\
    # trust.img
    && tools/trust_merger ${IMG_SIZE} ${PATH_FIXUP} RKTRUST/RK3399TRUST.ini \
\
    # copy content
    && cp rk3399_loader_*.bin uboot.img trust.img idbloader.img ${BOOT} \
    # copy flash tool
    && cp tools/rkdeveloptool "${BOOT}"

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/kernel.git kernel
ADD "packages/boot/kernel-rockchip.tar.xz" "${BUILD}"
    # copy patch
COPY "./packages/patch/" "${BUILD}/patch/"

# patch
RUN set -x \
    && cd kernel-rockchip \
    # realsense
    && export REALSENSE_PATCH=../patch/kernel/realsense \
    && for i in `ls ${REALSENSE_PATCH}`; do patch -p1 < ${REALSENSE_PATCH}/$i; done 

# kernel
RUN set -x \
    && cd kernel-rockchip \
    && make nanopi4_linux_defconfig \
    # make images
    && make nanopi4-images nanopi4-bootimg -j$(nproc)

# copy content
RUN cd kernel-rockchip \
    && cp kernel.img resource.img boot.img zboot.img "${BOOT}"

#----------------------------------------------------------------------------------------------------------------#

ENV ROOTFS "${BOOT}/rootfs"
RUN mkdir -p "${ROOTFS}" \
    && cd "${ROOTFS}" \
    && mkdir dev etc lib usr var proc tmp home root mnt sys

# busybox
ENV BUSYBOX_VERSION 1.30.1
    # wget https://github.com/mirror/busybox/archive/1_30_1.tar.gz
ADD "./packages/rootfs/busybox-${BUSYBOX_VERSION}.tar.xz" "${BUILD}"

RUN set -x \
    && cd "busybox-${BUSYBOX_VERSION}" \
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${ROOTFS}" install \
    && cp -r examples/bootfloppy/etc/* "${ROOTFS}/etc"

#----------------------------------------------------------------------------------------------------------------#

RUN cd "${BOOT}" \
    && tar cf /boot.tar *

#----------------------------------------------------------------------------------------------------------------#
