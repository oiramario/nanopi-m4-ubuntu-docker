FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.1" \
      email="oiramario@gmail.com"

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
ARG CORES
ENV JOBS $CORES

RUN cd /usr/bin \
    && ln -s aarch64-linux-gnu-gcc-8 aarch64-linux-gnu-gcc \
    && ln -s aarch64-linux-gnu-g++-8 aarch64-linux-gnu-g++

ENV BUILD "/opt/build"
WORKDIR ${BUILD}

#----------------------------------------------------------------------------------------------------------------#

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

RUN apt-get install -y \
                    # kernel
                    bc libssl-dev liblz4-tool

ENV BOOT "/opt/boot"
RUN mkdir -p "${BOOT}"


# build u-boot
ADD "./packages/boot/u-boot.tar.xz" "${BUILD}"
# git clone https://github.com/rockchip-linux/u-boot.git --depth 1 -b stable-4.4-rk3399-linux
RUN cd u-boot \
    && git pull \
    # cross compiler already installed
    && sed -i -e 's:../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:/usr/bin:' make.sh

ADD "./packages/boot/rkbin.tar.xz" "${BUILD}"
# git clone https://github.com/rockchip-linux/rkbin.git --depth 1
RUN cd rkbin \
    && git pull

RUN set -x \
    && cd u-boot \
    && ./make.sh rk3399 \

RUN cd u-boot \
    # for idbloader.img
    && ./tools/mkimage -T rksd -n rk3399 -d $(find ../rkbin/bin/rk33/ -name "rk3399_ddr_800MHz_v*.bin") idbloader.img \
    && cat $(find ../rkbin/bin/rk33/ -name "rk3399_miniloader_v*.bin") >> idbloader.img \
    # copy content outside
    && cp uboot.img trust.img rk3399_loader_*.bin idbloader.img "${BOOT}" \
    && cd ../rkbin/tools \
    && cp resource_tool rkdeveloptool parameter_gpt.txt "${BOOT}"


RUN cd "${BOOT}" \
    && tar cf /boot.tar *
