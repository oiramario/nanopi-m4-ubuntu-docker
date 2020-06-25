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
        # mpv
        python \
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



####################
# operating system #
####################

# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "${BUILD}/"
COPY "patch/u-boot" "$BUILD/patch/u-boot"
RUN set -x \
    && cd "u-boot" \
    # gcc9-no-Werror
    && PATCH="$BUILD/patch/u-boot" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && make rk3399_defconfig \
    && make -j$(nproc)


# kernel
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/kernel.tar.gz" "${BUILD}/"
RUN set -x \
    && cd kernel \
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "${BUILD}/"
COPY "patch/busybox" "$BUILD/patch/busybox"
RUN set -x \
    && cd "busybox" \
    # replace stime, static link
    && PATCH="$BUILD/patch/busybox" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && make defconfig \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${BUILD}/initramfs" install \
    && rm -f "${BUILD}/initramfs/linuxrc"

# init
COPY "archives/init" "${BUILD}/initramfs/"


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" "${BUILD}/"
ADD "packages/rk-rootfs-build.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "rk-rootfs-build" \
    # copy dptx.bin to initramfs
    && mkdir -p "${BUILD}/initramfs/lib/firmware/rockchip" \
    && cp "overlay-firmware/lib/firmware/rockchip/dptx.bin" "${BUILD}/initramfs/lib/firmware/rockchip/" \
    \
    # rockchip firmware
    && cp -rf overlay-firmware/etc "${ROOTFS}/" \
    && cp -rf overlay-firmware/system "${ROOTFS}/" \
    && cp -rf overlay-firmware/usr "${ROOTFS}/" \
    # /lib is symlink to /usr/lib in LTS 20.04
    && cp -rf overlay-firmware/lib "${ROOTFS}/usr/" \
    # 64bits wifi/bt
    && cd "${ROOTFS}/usr/bin" \
    && mv -f "brcm_patchram_plus1_64" "brcm_patchram_plus1" \
    && mv -f "rk_wifi_init_64" "rk_wifi_init" \
    # bt, wifi, audio firmware
    && mkdir -p "${ROOTFS}/system/lib/modules" \
    && find "${BUILD}/kernel/drivers/net/wireless/rockchip_wlan" -name "*.ko" | \
            xargs -n1 -i cp {} "${ROOTFS}/system/lib/modules" \
    \
    # power manager
    && cd "${BUILD}/rk-rootfs-build/overlay/etc/Powermanager" \
    && cp "triggerhappy.service" "${ROOTFS}/lib/systemd/system/" \
    && cp "power-key.sh" "${ROOTFS}/usr/bin/" \
    && mkdir -p "${ROOTFS}/etc/triggerhappy/triggers.d" \
    && cp "power-key.conf" "${ROOTFS}/etc/triggerhappy/triggers.d/" \
    && cp "triggerhappy" "${ROOTFS}/etc/init.d/" \
    \
    # udev rules
    && mkdir -p "${ROOTFS}/etc/udev/rules.d" \
    && cd "${BUILD}/rk-rootfs-build/overlay/etc/udev/rules.d" \
    && cp "50-hevc-rk3399.rules" \
          "50-mail.rules" \
          "50-vpu-rk3399.rules" \
          "60-media.rules" \
          "60-rga.rules" \
          "${ROOTFS}/etc/udev/rules.d/"


# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX="/opt/devkit"
RUN mkdir -p ${PREFIX}/include ${PREFIX}/lib
ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
RUN mkdir -p ${PKG_CONFIG_PATH}

COPY "archives/toolchain.cmake" "${BUILD}/"


# eudev
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/eudev.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd eudev \
    && autoreconf -vfi \
    && ./configure  --prefix="" \
                    --host="${HOST}" \
                    --enable-hwdb=yes \
                    --enable-rule-generator=yes \
                    --enable-mtd_probe=yes \
                    --disable-static \
                    --disable-blkid \
    && make -j$(nproc) \
    && make install \
    \
    # for cross-compile
    && cp -f /lib/pkgconfig/libudev.pc ${PKG_CONFIG_PATH}/ \
    && sed -i "s:prefix=:prefix=${PREFIX}:" ${PKG_CONFIG_PATH}/libudev.pc \
    && cp -f /include/libudev.h /include/udev.h ${PREFIX}/include/ \
    && cp -rfp /lib/libudev.so* ${PREFIX}/lib/ \
    # utils and configs
    && cp -f /bin/udevadm ${ROOTFS}/bin/ \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/bin/udevadm" \
    && cp -rfp /sbin/udevd /sbin/udevadm ${ROOTFS}/sbin/ \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/sbin/udevd" \
    && cp -rf /etc/udev ${ROOTFS}/etc/ \
    && cp -rf /lib/udev ${ROOTFS}/lib/ 



############
# run-time #
############

# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "alsa-lib" \
    && autoreconf -vfi \
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


# alsa-config
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-config.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "alsa-config" \
    && autoreconf -vfi \
    && ./configure  --prefix="${ROOTFS}" \
    && make install


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libdrm" \
    && ./autogen.sh --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --disable-debug \
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
#COPY "patch/libmali" "$BUILD/patch/libmali"
RUN set -x \
    && cd "libmali" \
    # # upgrade backends to r18p0
    # && PATCH="$BUILD/patch/libmali" \
    # && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DTARGET_SOC=rk3399 \
                -DDP_FEATURE=gbm \
                -DGPU_FEATURE=opencl \
                . \
    && make install \
    \
    # create gbm symlink for sdl
    && cd "${PREFIX}/lib" \
    && ln -s "libMali.so" "libgbm.so" \
    # OpenCL
    && mv ${PREFIX}/etc/OpenCL ${ROOTFS}/etc/ \
    && rm -rf ${PREFIX}/etc


# librga
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librga.tar.gz" "${BUILD}/"
RUN set -x \
    && cd librga \
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
COPY "patch/mpp" "$BUILD/patch/mpp"
RUN set -x \
    && cd "mpp" \
    # fix $prefix in rockhip_*.pc
    && PATCH="$BUILD/patch/mpp" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
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
    && autoreconf -vfi \
    && ./configure  CFLAGS="-I${PREFIX}/include" \
                    LDFLAGS="-L${PREFIX}/lib" \
                    --prefix="${PREFIX}" \
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
COPY "patch/ffmpeg" "$BUILD/patch/ffmpeg"
RUN set -x \
    && cd "ffmpeg" \
    # fix configure require librga
    # fix invalid use of av_alloc_size to avoid gcc warning
    && PATCH="$BUILD/patch/ffmpeg" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
    # make
    && ./configure  --prefix="${PREFIX}" \
                    --enable-cross-compile \
                    --cross-prefix=${CROSS_COMPILE} \
                    --arch=aarch64 \
                    --target-os=linux \
                    --pkg-config=/usr/bin/pkg-config \
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


# librealsense
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librealsense.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "librealsense" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
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
                . \
    && make -j$(nproc) \
    && make install \
    \
    # remove static library
    && rm -f ${PREFIX}/lib/librealsense-file.a \
    # setting-up permissions for realsense devices
    && mkdir -p "${ROOTFS}/etc/udev/rules.d/" \
    && cp "config/99-realsense-libusb.rules" "${ROOTFS}/etc/udev/rules.d/"


# sdl
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/sdl.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "sdl" \
    && mkdir "build" && cd "build" \
    &&  CFLAGS="-I${PREFIX}/include" \
        LDFLAGS="-L${PREFIX}/lib" \
        cmake   -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSDL_STATIC=OFF \
                -DSDL_SHARED=ON \
                .. \
    && make -j$(nproc) \
    && make install \
    \
    # remove static library
    && rm -f ${PREFIX}/lib/libSDL2main.a \
    # for cross-compile
    && mv ${PREFIX}/bin/sdl2-config /usr/local/bin/


# gdbserver
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gdb.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "gdb/gdb/gdbserver" \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --target="${HOST}" \
    && make -j$(nproc) \
    && make install \
    \
    # rename
    && cd ${PREFIX}/bin \
    && mv ${CROSS_COMPILE}gdbserver gdbserver



###############
# application #
###############

ARG Application


# mpv
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpv.tar.gz" "${BUILD}/"
RUN set -x \
    &&  if [ "$Application" != "" ]; then \
            cd "mpv" ;\
            ./bootstrap.py ;\
            ./waf configure CC=${CROSS_COMPILE}gcc \
                            CFLAGS="-I${PREFIX}/include -DEGL_NO_X11" \
                            LDFLAGS="-L${PREFIX}/lib" \
                            --prefix="${PREFIX}" \
                            --disable-debug \
                            --enable-libmpv-shared \
                            --enable-egl-drm \
                            --enable-sdl2 \
                            --disable-lua \
                            --disable-javascript \
                            --disable-libass \
                            ;\
            ./waf build -j$(nproc) ;\
            ./waf install ;\
            mv ${PREFIX}/etc/mpv ${ROOTFS}/etc/ ;\
        fi


# sdlpal
#----------------------------------------------------------------------------------------------------------------#
ADD "archives/pal.tar.gz" "${BUILD}/"
ADD "packages/sdlpal.tar.gz" "${BUILD}/"
RUN set -x \
    &&  if [ "$Application" != "" ]; then \
            cd "sdlpal/unix" ;\
            # do not link GL
            sed -i "s:# define PAL_HAS_GLSL 1:# define PAL_HAS_GLSLx 0:" "pal_config.h" ;\
            sed -i "s:LDFLAGS += -lGL -pthread:LDFLAGS += -pthread:" "Makefile" ;\
            # cross-compile
            sed -i "s:HOST =:HOST = ${CROSS_COMPILE}:" "Makefile" ;\
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
    && mkdir build && cd build \
    &&  CFLAGS="-DEGL_NO_X11" \
        LDFLAGS="-L${PREFIX}/lib" \
        cmake   -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
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


# glmark2
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/glmark2.tar.gz" "${BUILD}/"
RUN set -x \
    &&  if [ "$Application" != "" ]; then \
            cd glmark2 ;\
            ./waf configure CC=${CROSS_COMPILE}gcc \
                            CXX=${CROSS_COMPILE}g++ \
                            CFLAGS="-idirafter ${PREFIX}/include -DEGL_NO_X11" \
                            LDFLAGS="-L${PREFIX}/lib" \
                            --prefix="${PREFIX}" \
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
RUN set -x \
    &&  if [ "$UnitTest" != "" ]; then \
            cp -rfp ${BUILD}/media/* ${ROOTFS}/opt/ ;\
        fi


# rga_test
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    &&  if [ "$UnitTest" != "" ]; then \
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
RUN set -x \
    &&  if [ "$UnitTest" != "" ]; then \
            ${CROSS_COMPILE}g++ "${BUILD}/sdl_test/sdl_video_test.cpp" `sdl2-config --cflags --libs` -L"libudev" -o "${ROOTFS}/opt/sdl_video_test" ;\
            aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/sdl_video_test" ;\
        fi


# opencl_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/opencl_test.tar.gz" "${BUILD}/"
RUN set -x \
    &&  if [ "$UnitTest" != "" ]; then \
            cd opencl_test ;\
            ${CROSS_COMPILE}gcc "hellocl.c" $(pkg-config --cflags --libs OpenCL libdrm) -o "${ROOTFS}/opt/opencl_test" ;\
            aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/opencl_test" ;\
        fi


# realsense_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/realsense_test.tar.gz" "${BUILD}/"
RUN set -x \
    &&  if [ "$UnitTest" != "" ]; then \
            cd "realsense_test" ;\
            cmake   -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                    -DCMAKE_BUILD_TYPE=Release \
                    . \
                    ;\
            make -j$(nproc) ;\
            cp "gbm-drm-gles-cube" "${ROOTFS}/opt/realsense_test" ;\
            aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/realsense_test" ;\
        fi



##################
# pre-deployment #
##################

# k380 keyboard
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/k380-function-keys-conf.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "k380-function-keys-conf" \
    && make -j$(nproc) \
    && DESTDIR="${ROOTFS}" make install


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
           xargs ${CROSS_COMPILE}strip --strip-unneeded $f; \
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
