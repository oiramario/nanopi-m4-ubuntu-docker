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
                    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
                    make \
                    patch

# setup build environment
ENV CROSS_COMPILE "aarch64-linux-gnu-"
ENV ARCH arm64

ENV BUILD "/opt/build"
WORKDIR ${BUILD}

#----------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------#

RUN apt-get install -y \
                    # u-boot
                    bison flex \
                    # kernel
                    bc libssl-dev

ENV BOOT "/opt/boot"
RUN mkdir -p ${BOOT}

#----------------------------------------------------------------------------------------------------------------#

#+----------------------------+---------------------+-------------------+--------------------+----------------+--------------------------------------+
#| Partition                  |     Start Sector    | Number of Sectors |   Partition Size   | PartNum in GPT | Requirements                         |
#+----------------------------+----------+----------+--------+----------+--------------------+----------------+--------------------------------------+
#| MBR                        |        0 | 00000000 |      1 | 00000001 |       512 |  0.5KB |                |                                      |
#| Primary GPT                |        1 | 00000001 |     63 | 0000003F |     32256 | 31.5KB |                |                                      |
#| loader1                    |       64 | 00000040 |   7104 | 00001BC0 |   4096000 |  2.5MB |        1       | preloader (miniloader or U-Boot SPL) |
#| Vendor Storage             |     7168 | 00001C00 |    512 | 00000200 |    262144 |  256KB |                | SN, MAC and etc.                     |
#| Reserved Space             |     7680 | 00001E00 |    384 | 00000180 |    196608 |  192KB |                | Not used                             |
#| reserved1                  |     8064 | 00001F80 |    128 | 00000080 |     65536 |   64KB |                | legacy DRM key                       |
#| U-Boot ENV                 |     8128 | 00001FC0 |     64 | 00000040 |     32768 |   32KB |                |                                      |
#| reserved2                  |     8192 | 00002000 |   8192 | 00002000 |   4194304 |    4MB |                | legacy parameter                     |
#| loader2                    |    16384 | 00004000 |   8192 | 00002000 |   4194304 |    4MB |        2       | U-Boot or UEFI                       |
#| trust                      |    24576 | 00006000 |   8192 | 00002000 |   4194304 |    4MB |        3       | trusted-os like ATF, OP-TEE          |
#| boot(bootable must be set) |    32768 | 00008000 | 229376 | 00038000 | 117440512 |  112MB |        4       | kernel, dtb, extlinux.conf, ramdisk  |
#| rootfs                     |   262144 | 00040000 |    -   |     -    |     -     |    -MB |        5       | Linux system                         |
#| Secondary GPT              | 16777183 | 00FFFFDF |     33 | 00000021 |     16896 | 16.5KB |                |                                      |
#+----------------------------+----------+----------+--------+----------+-----------+--------+----------------+--------------------------------------+

# nanopc-t4:   rk3399-nanopi4-rev00.dtb
# nanopi-m4:   rk3399-nanopi4-rev01.dtb
# nanopi-neo4: rk3399-nanopi4-rev04.dtb

# GPT parameter
RUN echo "\
FIRMWARE_VER: 6.0.0\n\
MACHINE_MODEL: RK3399\n\
MACHINE_ID: 007\n\
MANUFACTURER: RK3399\n\
MAGIC: 0x5041524B\n\
ATAG: 0x00200800\n\
MACHINE: 3399\n\
CHECK_MASK: 0x80\n\
PWR_HLD: 0,0,A,0,1\n\
#uuid:rootfs=00000000-0000-0000-0000-00000000\n\
#KERNEL_IMG: 0x00280000\n\
FDT_NAME: rk3399-nanopi4-rev01.dtb\n\
#RECOVER_KEY: 1,1,0,20,0\n\
#in section; per section 512(0x200) bytes\n\
CMDLINE: console=ttyFIQ0 root=/dev/mmcblk1p6 rw rootwait \
mtdparts=rk29xxnand:\
0x00001F40@0x00000040(idbloader),\
0x00000080@0x00001F80(reserved1),\
0x00002000@0x00002000(reserved2),\
0x00002000@0x00004000(uboot),\
0x00002000@0x00006000(trust),\
0x00038000@0x00008000(boot:bootable),\
-@0x00040000(rootfs:grow)\
" > "${BOOT}/parameter"

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/u-boot.git u-boot
ADD "./packages/boot/u-boot.tar.xz" "${BUILD}"
    # git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/rkbin.git rkbin
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
    && cp rk3399_loader_*.bin idbloader.img uboot.img trust.img "${BOOT}"

#----------------------------------------------------------------------------------------------------------------#

    # git clone --depth 1 -b nanopi4-linux-v4.4.y https://github.com/friendlyarm/kernel-rockchip.git kernel
ADD "packages/boot/kernel.tar.xz" "${BUILD}"
    # copy patch
COPY "./packages/patch/" "${BUILD}/patch/"

# patch
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

# boot.img
RUN apt-get install -y \
                    # boot.img
                    dosfstools mtools

RUN set -x \
    && echo "\
label kernel-4.4\n\
    kernel /Image\n\
    fdt /rk3399-nanopi4-rev01.dtb\n\
    append earlyprintk console=ttyFIQ0,1500000n8 rw root=/dev/mmcblk1p7 rootfstype=ext4 init=/sbin/init\
" > "extlinux.conf" \
    && mkfs.vfat -n "boot" -S 512 -C ${BOOT}/boot.img $((20 * 1024)) \
    && mmd -i ${BOOT}/boot.img ::/extlinux \
    && mcopy -i ${BOOT}/boot.img -s extlinux.conf ::/extlinux/extlinux.conf \
    && mcopy -i ${BOOT}/boot.img -s kernel/arch/arm64/boot/Image :: \
    && mcopy -i ${BOOT}/boot.img -s kernel/arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev01.dtb :: \
    && rm extlinux.conf \
    && sync

#----------------------------------------------------------------------------------------------------------------#

ENV ROOTFS "${BOOT}/rootfs"
RUN mkdir -p "${ROOTFS}" \
    && cd "${ROOTFS}" \
    && mkdir dev etc lib usr var proc tmp home root mnt sys

    # git clone --depth 1 -b 1_30_stable https://github.com/mirror/busybox.git busybox
ADD "./packages/boot/busybox.tar.xz" "${BUILD}"

RUN set -x \
    && cd "busybox" \
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${ROOTFS}" install \
    && cp -r examples/bootfloppy/etc/* "${ROOTFS}/etc"

#----------------------------------------------------------------------------------------------------------------#

RUN cd "${BOOT}" \
    && tar cf /boot.tar *

#----------------------------------------------------------------------------------------------------------------#
