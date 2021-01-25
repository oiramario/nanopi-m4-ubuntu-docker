#######################################
# configure cross-compile environment #
#######################################

FROM ubuntu:focal
LABEL author="oiramario" \
      version="0.5.2" \
      email="oiramario@gmail.com"

USER root

# apt sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/" \
    && echo "\
deb ${SOURCES} focal main restricted universe multiverse \n\
deb ${SOURCES} focal-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list \
    # dns server
    && echo "nameserver 114.114.114.114" > /etc/resolv.conf

# reuses the cache
RUN apt-get update -y \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # compile
        git  patch  make  pkg-config  cmake \
        gcc  g++  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu \
        # u-boot
        bison  flex \
        # kernel
        bc  libssl-dev  kmod \
        # initramfs
        device-tree-compiler  cpio  genext2fs \
        # eudev
        gperf \
        # libdrm
        autoconf  xutils-dev  libtool  libpciaccess-dev \
        # libmali  mpv
        python3 python3-pip ninja-build \
        # gdb
        texinfo \
        # rootfs
        binfmt-support  qemu-user-static \
        # local:en_US.UTF-8
        locales \
    && locale-gen en_US.UTF-8


# setup build environment
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    TERM=screen \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH="arm64" \
    HOST="aarch64-linux-gnu" \
    BUILD="/root/build"

WORKDIR ${BUILD}

# manipulate options in a .config file
COPY "archives/config" "/bin/"


####################
# operating system #
####################

# kernel
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/kernel.tar.gz" "${BUILD}/"
RUN set -x \
    && cd kernel \
    # make
    && export KCFLAGS=" -Wno-psabi \
                        -Wno-address-of-packed-member \
                        -Wno-missing-attributes \
                        -Wno-array-bounds \
                        -Wno-incompatible-pointer-types" \
    && make nanopi4_linux_defconfig \
    && config   --enable MALI_MIDGARD_FOR_ANDROID \
                --disable MALI_MIDGARD_FOR_LINUX \
    && make -j$(nproc)


# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "u-boot" \
    # remove Werror
    && sed -i "s:KBUILD_CFLAGS	+= -fshort-wchar -Werror:KBUILD_CFLAGS	+= -fshort-wchar:" ./Makefile \
    # make
    # && export KCFLAGS=" -Wno-format-overflow \
    #                     -Wno-array-bounds \
    #                     -Wno-address-of-packed-member" \
    && make rk3399_defconfig \
    && config   --disable ROCKCHIP_FIT_IMAGE \
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
    && make -j$(nproc)


# rockchip binaries
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" "${BUILD}/"


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "busybox" \
    # make
    && export CFLAGS="  -Wno-unused-result \
                        -Wno-format-security \
                        -Wno-address-of-packed-member \
                        -Wno-format-truncation \
                        -Wno-format-overflow" \
              LDFLAGS="--static" \
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${BUILD}/initramfs" install


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rk-rootfs-build.tar.gz" "${BUILD}/"
RUN set -x \
    # firmware
    && cd "rk-rootfs-build/overlay-firmware" \
    # copy dptx.bin to initramfs
    && mkdir -p "${BUILD}/initramfs/lib/firmware/rockchip" \
    && cp "lib/firmware/rockchip/dptx.bin" "${BUILD}/initramfs/lib/firmware/rockchip/" \
    \
    && cp -rf system usr "${ROOTFS}/" \
    # /lib is symlink to /usr/lib since LTS 20.04
    && cp -rf lib/* "${ROOTFS}/lib/" \
    # 64bits wifi/bt
    && cd "${ROOTFS}/usr/bin" \
    && mv -f "brcm_patchram_plus1_64" "brcm_patchram_plus1" \
    && mv -f "rk_wifi_init_64" "rk_wifi_init" \
    # bt, wifi, audio firmware
    && mkdir -p "${ROOTFS}/system/lib/modules" \
    && find "${BUILD}/kernel/drivers/net/wireless/rockchip_wlan" -name "*.ko" | \
            xargs -n1 -i cp {} "${ROOTFS}/system/lib/modules" \
    && aarch64-linux-gnu-strip --strip-unneeded ${ROOTFS}/system/lib/modules/*.ko


# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX="/opt/devkit"
RUN mkdir -p ${PREFIX}/include ${PREFIX}/lib

ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
RUN mkdir -p ${PKG_CONFIG_PATH}

COPY "archives/toolchain.cmake" "${BUILD}/"
COPY "archives/cross_file_aarch64.txt" "${BUILD}/"

RUN pip3 install meson


# eudev
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/eudev.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd eudev \
    && autoreconf -vfi \
    && export CFLAGS="  -Wno-format-truncation \
                        -Wno-unused-result \
                        -Wp,-w" \
    && ./configure  --host=${HOST} \
                    --sysconfdir=/etc \
                    --disable-static \
    && make -j$(nproc) \
    && make install \
    \
    # udev write paths to code that manual install to ${PREFIX}
    && cp -f /usr/lib/pkgconfig/libudev.pc ${PKG_CONFIG_PATH}/ \
    && sed -i "s:prefix=/usr:prefix=${PREFIX}:" ${PKG_CONFIG_PATH}/libudev.pc \
    && cp -f /usr/include/libudev.h /usr/include/udev.h ${PREFIX}/include/ \
    && cp -rfp /usr/lib/libudev.so* ${PREFIX}/lib/ \
    # utils and configs
    && cp -f /bin/udevadm ${ROOTFS}/bin/ \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/bin/udevadm" \
    && cp -rfp /sbin/udevd /sbin/udevadm ${ROOTFS}/sbin/ \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/sbin/udevd" \
    && cp -rf /etc/udev ${ROOTFS}/etc/ \
    && cp -rf /usr/lib/udev ${ROOTFS}/usr/lib/ \
    && mv ${ROOTFS}/etc/udev/hwdb.d ${ROOTFS}/usr/lib/udev/ \
    && mkdir -p ${ROOTFS}/etc/udev/hwdb.d



############
# run-time #
############

# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "alsa-lib" \
    && autoreconf -vfi \
    && export CFLAGS="  -Wno-address-of-packed-member \
                        -Wno-unused-result" \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --with-debug=no \
                    --enable-shared \
                    --with-configdir=/usr/share/alsa \
    && make -j$(nproc) \
    && make install \
    \
    # config files
    && cp -rfp /usr/share/alsa ${ROOTFS}/usr/share/


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libdrm" \
    # make
    && export CFLAGS="  -Wno-cpp \
                        -Wno-format-truncation" \
    && ./autogen.sh --prefix="${PREFIX}" \
                    --host="${HOST}" \
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
    && make install


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libmali" \
    # make
    && mkdir build && cd build \
    && meson .. . \
                --prefix="${PREFIX}" \
                --cross-file ${BUILD}/cross_file_aarch64.txt \
                -Darch=aarch64 \
                -Dgpu=midgard-t86x \
                -Dversion=r18p0 \
                -Dsubversion=none \
                -Dplatform=gbm \
                -Dopencl-icd=false \
                -Dwith-overlay=false \
    && meson compile \
    && meson install


# librga
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librga.tar.gz" "${BUILD}/"
RUN set -x \
    && cd librga \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
    && make -j$(nproc) \
    && make install


# mpp
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpp.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "mpp" \
    # make
    && export CFLAGS="  -Wno-stringop-truncation \
                        -Wno-absolute-value" \
              CXXFLAGS="-Wno-stringop-truncation" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DENABLE_SHARED=ON \
                -DENABLE_STATIC=OFF \
                -DHAVE_DRM=ON \
                . \
    && make -j$(nproc) \
    && make install


# libusb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libusb.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd "libusb" \
    # make
    && autoreconf -vfi \
    && export   CFLAGS="-I${PREFIX}/include \
                        -Wno-format-zero-length" \
                LDFLAGS="-L${PREFIX}/lib" \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --enable-shared \
                    --disable-static \
    && make -j$(nproc) \
    && make install


# zlib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/zlib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd zlib \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DINSTALL_PKGCONFIG_DIR="${PREFIX}/lib/pkgconfig" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
    && make -j$(nproc) \
    && make install \
    \
    # remove static library
    && rm -f ${PREFIX}/lib/libz.a


# libjpeg
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libjpeg.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libjpeg \
    # make
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DENABLE_STATIC=OFF \
                -DENABLE_SHARED=TRUE \
                -DENABLE_STATIC=FALSE \
                .. \
    && make -j$(nproc) \
    && make install


# libpng
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libpng.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libpng \
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
    && make install


# ffmpeg
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ffmpeg.tar.gz" "${BUILD}/"
#COPY "patch/ffmpeg" "$BUILD/patch/ffmpeg"
RUN set -x \
    && cd "ffmpeg" \
    # # patch
    # && PATCH="$BUILD/patch/ffmpeg" \
    # && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && sed -i "s:-lrga:-lrga -ldrm:" ./configure \
    && export ECFLAGS=" -Wno-deprecated-declarations \
                        -Wno-stringop-overflow \
                        -Wno-strict-prototypes \
                        -Wno-format-truncation \
                        -Wno-stringop-truncation \
                        -Wno-cpp \
                        -Wno-alloc-size-larger-than \
                        -Wno-format-overflow \
                        -Wno-discarded-qualifiers \
                        -Wno-unused-but-set-variable \
                        -Wno-unused-function \
                        -Wno-declaration-after-statement " \
    && ./configure  --prefix="${PREFIX}" \
                    --enable-cross-compile \
                    --cross-prefix=${CROSS_COMPILE} \
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
    && make install


# librealsense [option: --build-arg RS=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG RS
ADD "packages/librealsense.tar.gz" "${BUILD}/"
COPY "patch/librealsense" "$BUILD/patch/librealsense"
RUN if [ "${RS}" = "ON" ]; then \
        set -x ;\
        cd "librealsense" ;\
        # patch
        PATCH="$BUILD/patch/librealsense" ;\
        for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done ;\
        # make
        export CXXFLAGS="-Wno-deprecated \
                         -Wno-placement-new" ;\
        cmake   -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                # only shared
                -DBUILD_SHARED_LIBS=ON \
                # downloading slowly
                -DBUILD_WITH_TM2=OFF \
                -DIMPORT_DEPTH_CAM_FW=OFF \
                # no examples
                -DBUILD_GRAPHICAL_EXAMPLES=OFF \
                -DBUILD_GLSL_EXTENSIONS=OFF \
                -DBUILD_EXAMPLES=OFF \
                # dynamic link CRT
                -DBUILD_WITH_STATIC_CRT=OFF \
                # avoid kernel patch
                -DFORCE_RSUSB_BACKEND=ON \
                . ;\
        make -j$(nproc) ;\
        make install ;\
        \
        # remove static library
        rm -f ${PREFIX}/lib/librealsense-file.a ;\
        # setting-up permissions for realsense devices
        mkdir -p "${ROOTFS}/etc/udev/rules.d/" ;\
        cp "config/99-realsense-libusb.rules" "${ROOTFS}/etc/udev/rules.d/" ;\
    fi


# sdl [option: --build-arg SDL=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG SDL
ADD "packages/sdl.tar.gz" "${BUILD}/"
RUN if [ "${SDL}" = "ON" ]; then \
        set -x ;\
        cd "sdl" ;\
        # make
        mkdir "build" && cd "build" ;\
        export  CFLAGS="-I${PREFIX}/include -DEGL_NO_X11 -Wno-shadow" \
                LDFLAGS="-L${PREFIX}/lib" ;\
        cmake   -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSDL_STATIC=OFF \
                -DSDL_SHARED=ON \
                .. ;\
        make -j$(nproc) ;\
        make install ;\
        \
        # remove static library
        rm -f ${PREFIX}/lib/libSDL2main.a ;\
        # for cross-compile
        mv ${PREFIX}/bin/sdl2-config /usr/local/bin/ ;\
    fi


# gdbserver [option: --build-arg GDB=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG GDB
ADD "packages/gdb.tar.gz" "${BUILD}/"
RUN if [ "${GDB}" = "ON" ]; then \
        set -x ;\
        cd "gdb/gdb/gdbserver" ;\
        # make
        export CFLAGS="-Wno-stringop-truncation" ;\
        ./configure --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --target="${HOST}" ;\
        make -j$(nproc) ;\
        make install ;\
        \
        # rename
        cd ${PREFIX}/bin ;\
        mv ${CROSS_COMPILE}gdbserver gdbserver ;\
    fi


###############
# application #
###############

# mpv [option: --build-arg MPV=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG MPV
ADD "packages/mpv.tar.gz" "${BUILD}/"
RUN if [ "${MPV}" = "ON" ]; then \
        set -x ;\
        cd "mpv" ;\
        ./bootstrap.py ;\
        export  CC=${CROSS_COMPILE}gcc \
                CFLAGS="-I${PREFIX}/include \
                        -DEGL_NO_X11 \
                        -Wno-stringop-truncation \
                        -Wno-format-truncation \
                        -Wno-unused-label" \
                LDFLAGS="-L${PREFIX}/lib" ;\
        \
        ./waf configure --prefix="${PREFIX}" \
                        --disable-debug \
                        --enable-libmpv-shared \
                        --enable-egl-drm \
                        --enable-sdl2 \
                        --disable-lua \
                        --disable-javascript \
                        --disable-libass ;\
        \
        ./waf build -j$(nproc) ;\
        ./waf install ;\
        mv ${PREFIX}/etc/mpv ${ROOTFS}/etc/ ;\
    fi


# sdlpal [option: --build-arg PAL=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG PAL
ADD "archives/pal.tar.gz" "${BUILD}/"
ADD "packages/sdlpal.tar.gz" "${BUILD}/"
COPY "patch/sdlpal" "$BUILD/patch/sdlpal"
RUN if [ "${PAL}" = "ON" ]; then \
        set -x ;\
        # patch
        cd "sdlpal" ;\
        PATCH="$BUILD/patch/sdlpal" ;\
        for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done ;\
        # make
        cd "unix" ;\
        export CCFLAGS="-Wno-dangling-else \
                        -Wno-unused-variable \
                        -Wno-stringop-truncation \
                        -Wno-missing-braces \
                        -Wno-restrict \
                        -Wno-unused-result \
                        -Wno-unused-function \
                        -Wno-maybe-uninitialized \
                        -Wno-sign-compare \
                        -Wno-sizeof-pointer-memaccess \
                        -Wno-switch \
                        " ;\
        \
        make -j$(nproc) ;\
        # copy bin and data
        cp -rpf ${BUILD}/pal ${ROOTFS}/opt/ ;\
        cp "sdlpal" "${ROOTFS}/opt/pal/" ;\
        aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/pal/sdlpal" ;\
    fi


# gl4es
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gl4es.tar.gz" "${BUILD}/"
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
    && make -j$(nproc)

RUN set -x \
    && cd gl4es \
    && cp lib/libGL.so.1 ${PREFIX}/lib/ \
    && cd ${PREFIX}/lib \
    && ln -s libGL.so.1 libGL.so


# glmark2 [option: --build-arg GLMARK2=ON]
#----------------------------------------------------------------------------------------------------------------#
ARG GLMARK2
ADD "packages/glmark2.tar.gz" "${BUILD}/"
RUN if [ "${GLMARK2}" = "ON" ]; then \
        set -x ;\
        cd glmark2 ;\
        export  CC=${CROSS_COMPILE}gcc \
                CXX=${CROSS_COMPILE}g++ \
                CFLAGS="-idirafter ${PREFIX}/include -DEGL_NO_X11" \
                LDFLAGS="-L${PREFIX}/lib" ;\
        \
        ./waf configure --prefix="${PREFIX}" \
                        --no-debug \
                        --data-path="/opt/glmark2/data" \
                        --with-flavors=drm-glesv2,drm-gl \
                        ;\
        ./waf build -j$(nproc) ;\
        ./waf install ;\
        # copy bin and data
        mv /opt/glmark2 ${ROOTFS}/opt/ ;\
        cd "${PREFIX}/bin/" ;\
        mv "glmark2-drm" "glmark2-es2-drm" ${ROOTFS}/opt/glmark2/ ;\
        cd ${ROOTFS}/opt/glmark2/ ;\
        aarch64-linux-gnu-strip --strip-unneeded "glmark2-drm" "glmark2-es2-drm" ;\
    fi



#############
# unit-test #
#############

ARG UnitTest

# media
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/media/*" "${BUILD}/media/"
RUN if [ "${UnitTest}" = "ON" ]; then \
        set -x ;\
        cp -rfp ${BUILD}/media/* ${ROOTFS}/opt/ ;\
    fi


# rga_test
#----------------------------------------------------------------------------------------------------------------#
RUN if [ "${UnitTest}" = "ON" ]; then \
        set -x ;\
        cd librga/demo ;\
        mkdir build ;\
        cd build ;\
        cmake   -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
                ;\
        make -j$(nproc) ;\
        make install ;\
    fi


# sdl_test
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/sdl_video_test.cpp" "${BUILD}/sdl_test/"
RUN if [ "${SDL}" = "ON" ] && [ "${UnitTest}" = "ON" ]; then \
        set -x ;\
        ${CROSS_COMPILE}g++ "${BUILD}/sdl_test/sdl_video_test.cpp" `sdl2-config --cflags --libs` -L"libudev" -o "${ROOTFS}/opt/sdl_video_test" ;\
        aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/sdl_video_test" ;\
    fi


# opencl_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/opencl_test.tar.gz" "${BUILD}/"
RUN if [ "${UnitTest}" = "ON" ]; then \
        set -x ;\
        cd opencl_test ;\
        sed -i '1i #include <stdlib.h>' hellocl.c ;\
        ${CROSS_COMPILE}gcc "hellocl.c" $(pkg-config --cflags --libs OpenCL libdrm) -Wno-implicit-function-declaration -o "${ROOTFS}/opt/opencl_test" ;\
        aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/opencl_test" ;\
    fi


# realsense_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/realsense_test.tar.gz" "${BUILD}/"
RUN if [ "${RS}" = "ON" ] && [ ${UnitTest} = "ON" ]; then \
        set -x ;\
        cd realsense_test ;\
        mkdir build ;\
        cd build ;\
        cmake   -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
                ;\
        make -j$(nproc) ;\
        cp "gbm-drm-gles-cube" "${ROOTFS}/opt/realsense_test" ;\
        aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/realsense_test" ;\
    fi



##################
# pre-deployment #
##################

# strip so
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    && find ${PREFIX}/lib -name \*.so* | xargs ${CROSS_COMPILE}strip --strip-unneeded \
    && cp -rfp ${PREFIX}/lib/*.so* "${ROOTFS}/usr/lib/"


# strip exe
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    && cd ${PREFIX}/bin \
    && for f in `find ./ -executable -type f`; do \
            xargs ${CROSS_COMPILE}strip --strip-unneeded $f ;\
       done \
    && cp -rfp ${PREFIX}/bin/* "${ROOTFS}/usr/bin/"


# overlay
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/rootfs/" "${ROOTFS}/"


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO="/root/distro"
ENV DEVKIT="/root/devkit"
WORKDIR "/root/scripts"
