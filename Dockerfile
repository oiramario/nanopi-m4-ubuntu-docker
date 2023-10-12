#######################################
# configure cross-compile environment #
#######################################

FROM ubuntu:focal
LABEL author="oiramario" \
      version="0.5.5" \
      email="oiramario@gmail.com"

USER root

# apt sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/" \
    && echo "\
deb ${SOURCES} focal main restricted universe multiverse \n\
deb ${SOURCES} focal-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list

# reuses the cache
RUN apt-get update -y \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # compile
        make  pkg-config  cmake \
        git  gcc  g++  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu \
        # u-boot
        bison  flex  python3 \
        # kernel
        bc  libssl-dev  kmod \
        # initramfs
        device-tree-compiler  cpio  genext2fs \
        # libdrm
        autoconf  xutils-dev  libtool  libpciaccess-dev \
        # mpv
        python \
        # rootfs
        binfmt-support  qemu-user-static \
        # local:en_US.UTF-8
        locales \
    && locale-gen en_US.UTF-8


# setup build environment
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    TERM=screen

ENV BUILD="/root/modules"
WORKDIR ${BUILD}

ENV ELAPSED_BEGIN="export start_stamp=\$(date +%s)"
ENV ELAPSED_END="end_stamp=\$(date +%s); \
                         elapsed=\$(( \${end_stamp} - \${start_stamp} )) \
                         hour=\$(( \${elapsed}/3600 )); \
                         min=\$(( (\${elapsed}-\${hour}*3600)/60 )); \
                         sec=\$(( \${elapsed}-\${hour}*3600-\${min}*60 )); \
                         echo Time taken to execute commands is \${hour}:\${min}:\${sec}."


####################
# operating system #
####################

# kernel
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/kernel.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "kernel" \
    && eval ${ELAPSED_BEGIN} \
    && export   ARCH="arm64" \
                CROSS_COMPILE="aarch64-linux-gnu-" \
    && make nanopi4_linux_defconfig \
    && make -j$(nproc) \
    && mkdir kmodules \
    && make INSTALL_MOD_PATH=kmodules modules -j$(nproc) \
    && make INSTALL_MOD_PATH=kmodules modules_install \
    && eval ${ELAPSED_END}


# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/uboot.tar.gz" ${BUILD}/
RUN set -x \
    && cd "uboot" \
    && eval ${ELAPSED_BEGIN} \
    # remove Werror
    && sed -i "s:-Werror::" ./Makefile \
    # make
    && export   ARCH="arm64" \
                CROSS_COMPILE="aarch64-linux-gnu-" \
    && make nanopi-m4-rk3399_defconfig \
    && ${BUILD}/kernel/scripts/config \
                --disable ROCKCHIP_FIT_IMAGE \
                --disable ROCKCHIP_UIMAGE \
                --disable CMD_BOOT_ROCKCHIP \
                --disable CONFIG_TEST_ROCKCHIP \
                --disable ANDROID_BOOTLOADER \
                --disable ANDROID_BOOT_IMAGE \
                --disable CMD_BOOT_ANDROID \
                --disable ROCKCHIP_EARLY_DISTRO_DTB \
                --disable ENV_IS_NOWHERE \
                --enable ENV_IS_IN_MMC \
                --set-val ENV_OFFSET 0x3F8000 \
    && make -j$(nproc) \
    && eval ${ELAPSED_END}


# rockchip binaries
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" ${BUILD}/


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" ${BUILD}/
RUN set -x \
    && cd "busybox" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && export   ARCH="arm64" \
                CROSS_COMPILE="aarch64-linux-gnu-" \
                CFLAGS="-Wno-unused-result \
                        -Wno-format-security \
                        -Wno-address-of-packed-member \
                        -Wno-format-truncation \
                        -Wno-format-overflow" \
                LDFLAGS="--static" \
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${BUILD}/initramfs" install \
    && eval ${ELAPSED_END}


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/rootfs.tar.gz" ${BUILD}/


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rk-rootfs-build.tar.gz" ${BUILD}/
RUN set -x \
    && eval ${ELAPSED_BEGIN} \
    && cd "${BUILD}/kernel" \
    && KERNEL_VER=`make kernelrelease` \
    # firmware
    && cd "${BUILD}/rk-rootfs-build/overlay-firmware" \
    # copy dptx.bin to initramfs
    && mkdir -p "${BUILD}/initramfs/lib/firmware/rockchip" \
    && cp "lib/firmware/rockchip/dptx.bin" "${BUILD}/initramfs/lib/firmware/rockchip/" \
    && cp -rf system usr ${ROOTFS}/ \
    # /lib is symlink to /usr/lib since LTS 20.04
    && cp -rf lib/* "${ROOTFS}/lib/" \
    # 64bits wifi/bt
    && cd "${ROOTFS}/usr/bin" \
    && mv -f "brcm_patchram_plus1_64" "brcm_patchram_plus1" \
    && mv -f "rk_wifi_init_64" "rk_wifi_init" \
    # bt, wifi, audio firmware
    && mkdir -p "${ROOTFS}/system/lib/modules" \
    && cd "${BUILD}/kernel/kmodules/lib/modules/${KERNEL_VER}/kernel/drivers/net/wireless/rockchip_wlan/" \
    && find . -name "*.ko" | xargs -n1 -i cp {} "${ROOTFS}/system/lib/modules/" \
    && aarch64-linux-gnu-strip --strip-unneeded ${ROOTFS}/system/lib/modules/*.ko \
    && eval ${ELAPSED_END}


# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX="/opt/devkit"
RUN mkdir -p "${PREFIX}/include ${PREFIX}/lib ${PREFIX}/bin"

ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
RUN mkdir -p "${PKG_CONFIG_PATH}"

COPY "archives/toolchain.cmake" ${BUILD}/


############
# run-time #
############

# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" ${BUILD}/
RUN set -x \
    && cd "alsa-lib" \
    && eval ${ELAPSED_BEGIN} \
    && autoreconf -vfi \
    && ./configure  --prefix=${PREFIX} \
                    --host="aarch64-linux-gnu" \
                    --with-debug=no \
                    --enable-shared \
                    --with-configdir=/usr/share/alsa \
    && make -j$(nproc) \
    && make install \
    # config files
    && cp -rfp /usr/share/alsa ${ROOTFS}/usr/share/ \
    && eval ${ELAPSED_END}


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" ${BUILD}/
RUN set -x \
    && cd "libdrm" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && ./autogen.sh --prefix=${PREFIX} \
                    --host="aarch64-linux-gnu" \
                    --disable-dependency-tracking \
                    --disable-static \
                    --enable-shared \
                    --enable-udev \
                    --disable-cairo-tests \
                    --disable-manpages \
                    --disable-intel \
                    --disable-vmwgfx \
                    --disable-radeon \
                    --disable-amdgpu \
                    --disable-nouveau \
                    --disable-freedreno \
                    --disable-vc4 \
                    --disable-valgrind \
                    --disable-omap-experimental-api \
                    --disable-etnaviv-experimental-api \
                    --disable-exynos-experimental-api \
                    --disable-tegra-experimental-api \
                    --enable-rockchip-experimental-api \
    && make -j$(nproc) \
    && make install \
    && eval ${ELAPSED_END}


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" ${BUILD}/
RUN set -x \
    && cd "libmali" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DTARGET_SOC="rk3399" \
                -DDP_FEATURE="gbm" \
                .. \
    && make install \
    # OpenCL ICD
    && mv "${PREFIX}/etc/OpenCL" "${ROOTFS}/etc/" \
    && rm -rf "${PREFIX}/etc" \
    && eval ${ELAPSED_END}


# librga
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librga.tar.gz" ${BUILD}/
RUN set -x \
    && cd "librga" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TARGET=cmake_linux ..\
    && make -j$(nproc) \
    && cp librga.a librga.so ${PREFIX}/lib/ \
    && mkdir -p "${PREFIX}/include/rga" \
    && cd ../include \
    && cp drmrga.h GrallocOps.h rga.h RgaApi.h RgaMutex.h RgaSingleton.h RgaUtils.h RockchipRga.h ${PREFIX}/include/rga/ \
    && cd ../im2d_api \
    && cp *.h ${PREFIX}/include/rga/ \
    && eval ${ELAPSED_END}


# mpp
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpp.tar.gz" ${BUILD}/
RUN set -x \
    && cd "mpp" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DENABLE_SHARED=ON \
                -DENABLE_STATIC=OFF \
                -DHAVE_DRM=ON \
                . \
    && make -j$(nproc) \
    && make install \
    && eval ${ELAPSED_END}


# zlib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/zlib.tar.gz" ${BUILD}/
RUN set -x \
    && cd "zlib" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DINSTALL_PKGCONFIG_DIR="${PREFIX}/lib/pkgconfig" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
    && make -j$(nproc) \
    && make install \
    && rm -f ${PREFIX}/lib/libz.a \
    && eval ${ELAPSED_END}



# libjpeg
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libjpeg.tar.gz" ${BUILD}/
RUN set -x \
    && cd "libjpeg" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DENABLE_SHARED=TRUE \
                -DENABLE_STATIC=FALSE \
                .. \
    && make -j$(nproc) \
    && make install \
    && eval ${ELAPSED_END}


# libpng
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libpng.tar.gz" ${BUILD}/
RUN set -x \
    && cd "libpng" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DPNG_SHARED=ON \
                -DPNG_STATIC=OFF \
                -DPNG_TESTS=OFF \
                .. \
    && make -j$(nproc) \
    && make install \
    && eval ${ELAPSED_END}


# ffmpeg
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ffmpeg.tar.gz" ${BUILD}/
RUN set -x \
    && cd "ffmpeg" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && sed -i "s:-lrga:-lrga -ldrm:" ./configure \
    && ./configure  --prefix=${PREFIX} \
                    --enable-cross-compile \
                    --cross-prefix=aarch64-linux-gnu- \
                    --arch=aarch64 \
                    --target-os=linux \
                    --pkg-config=$(which pkg-config) \
                    --extra-ldflags="-L${PREFIX}/lib" \
                    --enable-rpath \
                    --enable-shared \
                    --disable-static \
                    --disable-debug \
                    --disable-doc \
                    --enable-nonfree \
                    --enable-gpl \
                    --enable-version3 \
                    --enable-rkmpp \
                    --enable-libdrm \
                    --enable-librga \
    && make -j$(nproc) \
    && make install \
    && eval ${ELAPSED_END}


# sdl
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/sdl.tar.gz" ${BUILD}/
RUN set -x \
    && cd "sdl" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && mkdir build && cd build \
    # use kmsdrm only
    && export   CFLAGS="-DEGL_NO_X11" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSDL_STATIC=OFF \
                -DSDL_SHARED=ON \
                .. \
    && make -j$(nproc) \
    && make install \
    && mv "${PREFIX}/bin/sdl2-config" "/usr/local/bin/" \
    && eval ${ELAPSED_END}


# mpv
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpv.tar.gz" ${BUILD}/
COPY "archives/media/*" "${ROOTFS}/opt/"
RUN set -x \
    && cd "mpv" \
    && eval ${ELAPSED_BEGIN} \
    # make
    && python3 ./bootstrap.py \
    && export   ARCH=arm64 \
                CC=aarch64-linux-gnu-gcc \
                CFLAGS="-I${PREFIX}/include -DEGL_NO_X11" \
    && ./waf configure  --prefix=${PREFIX} \
                        --disable-debug \
                        --enable-libmpv-shared \
                        --enable-egl-drm \
                        --enable-sdl2 \
                        --disable-lua \
                        --disable-javascript \
                        --disable-libass \
                        --disable-zlib \
    && ./waf build -j$(nproc) \
    && ./waf install \
    && mv "${PREFIX}/etc/mpv" "${ROOTFS}/etc/" \
    && eval ${ELAPSED_END}


# gl4es
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gl4es.tar.gz" ${BUILD}/
RUN set -x \
    && cd gl4es \
    # make
    && mkdir build && cd build \
    && export   CFLAGS="-DEGL_NO_X11" \
                LDFLAGS="-L${PREFIX}/lib" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSTATICLIB=OFF \
                -DNOX11=ON \
                -DGBM=ON \
                -DDEFAULT_ES=2 \
                -DUSE_CLOCK=ON \
                .. \
    && make -j$(nproc) \
    && cp ../lib/libGL.so.1 ${PREFIX}/lib/ \
    && cd ${PREFIX}/lib \
    && ln -s libGL.so.1 libGL.so


# sdlpal
#----------------------------------------------------------------------------------------------------------------#
ADD "archives/pal.tar.gz" ${BUILD}/
ADD "packages/sdlpal.tar.gz" ${BUILD}/
COPY "patch/sdlpal" "$BUILD/patch/sdlpal"
RUN apt-get -y install patch
RUN set -x \
    && cd "sdlpal" \
    && PATCH="$BUILD/patch/sdlpal" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && rm -rf .github \
    && cd "unix" \
    && export CROSS_COMPILE="aarch64-linux-gnu-" \
              CCFLAGS="-Wno-dangling-else \
                       -Wno-unused-variable \
                       -Wno-stringop-truncation \
                       -Wno-missing-braces \
                       -Wno-restrict \
                       -Wno-unused-result \
                       -Wno-unused-function \
                       -Wno-maybe-uninitialized \
                       -Wno-sign-compare \
                       -Wno-sizeof-pointer-memaccess \
                       -Wno-switch" \
    && make -j$(nproc) \
    # copy bin and data
    && cp -rpf ${BUILD}/pal ${ROOTFS}/opt/ \
    && cp "sdlpal" "${ROOTFS}/opt/pal/" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/pal/sdlpal"



##################
# pre-deployment #
##################

# strip
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    # so
    && find ${PREFIX}/lib -name \*.so* | xargs aarch64-linux-gnu-strip --strip-unneeded \
    && mkdir -p "${ROOTFS}/usr/lib/" \
    && cp -rfp ${PREFIX}/lib/*.so* "${ROOTFS}/usr/lib/" \
    # bin
    && cd ${PREFIX}/bin \
    && for f in `find ./ -executable -type f`; do \
           xargs aarch64-linux-gnu-strip --strip-unneeded $f ;\
       done \
    && cp -rfp ${PREFIX}/bin/* "${ROOTFS}/usr/bin/"


# overlay
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/rootfs/" ${ROOTFS}/


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV NANOPI4_DISTRO="/root/distro"
ENV NANOPI4_DEVKIT="/root/devkit"
WORKDIR "/root/scripts"
