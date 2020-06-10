#######################################
# configure cross-compile environment #
#######################################

FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.4.0" \
      email="oiramario@gmail.com"

# apt sources
RUN cat << EOF > /etc/apt/sources.list \
    && SOURCES="http://mirror.tuna.tsinghua.edu.cn/ubuntu/" \
    && echo "\
deb ${SOURCES} bionic main restricted universe multiverse \n\
deb ${SOURCES} bionic-updates main restricted universe multiverse \n\
" > /etc/apt/sources.list \
    # dns server
    && echo "nameserver 114.114.114.114" > /etc/resolv.conf

# reuses the cache
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # compile
        git  patch  make  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  pkg-config  cmake \
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

USER root

WORKDIR ${BUILD}



####################
# operating system #
####################

# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "u-boot" \
    # make
    && make rk3399_defconfig \
    && make -j$(nproc)


# kernel
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/kernel.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "kernel" \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "busybox" \
    # make
    && make defconfig \
    # static link
    && sed -i "s:# CONFIG_STATIC is not set:CONFIG_STATIC=y:" .config \
    && make -j$(nproc) \
    && make CONFIG_PREFIX="${BUILD}/initramfs" install

# init
COPY "archives/initramfs/*" "${BUILD}/initramfs/"
RUN set -x \
    && rm -f "linuxrc"


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
    && cp -rf overlay-firmware/* "${ROOTFS}/" \
    && cd "${ROOTFS}/usr/bin" \
    # 64bits wifi/bt
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
          "60-drm.rules" \
          "${ROOTFS}/etc/udev/rules.d/" \
    && cp "${BUILD}/rk-rootfs-build/overlay/usr/local/bin/drm-hotplug.sh" "${ROOTFS}/usr/local/bin/"



############
# run-time #
############

# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX="/opt/devkit"
ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
COPY "archives/toolchain.cmake" "${BUILD}/"


# eudev
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/eudev.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd eudev \
    && autoreconf -vfi \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --enable-hwdb=yes \
                    --enable-rule-generator=yes \
                    --enable-mtd_probe=yes \
                    --disable-static \
                    --disable-blkid \
                    --disable-kmod \
    && make -j$(nproc) \
    && make install

RUN set -x \ 
    && cp -rf ${PREFIX}/etc/udev ${ROOTFS}/etc/ \
    && cp -f ${PREFIX}/bin/udevadm ${ROOTFS}/bin/ \
    && cp -f ${PREFIX}/sbin/udevadm ${PREFIX}/sbin/udevd ${ROOTFS}/sbin/ \
    && cp -rf ${PREFIX}/lib/udev ${ROOTFS}/lib/


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libdrm" \
    && ./autogen.sh --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --disable-intel \
                    --disable-vmwgfx \
                    --disable-radeon \
                    --disable-amdgpu \
                    --disable-nouveau \
                    --disable-freedreno \
                    --disable-vc4 \
                    --enable-rockchip-experimental-api \
    && make -j$(nproc) \
    && make install


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libmali" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DTARGET_SOC=rk3399 \
                -DDP_FEATURE=gbm \
                . \
    && make install

# create gbm symlink
RUN set -x \
    && cd "${PREFIX}/lib" \
    && ln -s "libMali.so" "libgbm.so"


# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "alsa-lib" \
    && autoreconf -vfi \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --disable-python \
                    --enable-shared \
    && make -j$(nproc) \
    && make install


# mpp
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpp.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "mpp" \
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
    && make install


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
                -DM_LIBRARY="/usr/aarch64-linux-gnu/lib" \
                -DCMAKE_BUILD_TYPE=Release \
                -DPNG_STATIC=OFF \
                -DPNG_EXECUTABLES=OFF \
                -DPNG_TESTS=OFF \
                .. \
    && make -j$(nproc) \
    && make install


# x264
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/x264.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "x264" \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --cross-prefix="${CROSS_COMPILE}" \
                    --enable-static \
                    --enable-pic \
                    --disable-cli \
                    --disable-asm \
                    --disable-opencl \
                    --disable-swscale \
    && make -j$(nproc) \
    && make install


# ffmpeg
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ffmpeg.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "ffmpeg" \
    && LDFLAGS="-L${PREFIX}/lib" \
       ./configure  --prefix="${PREFIX}" \
                    --target-os="linux" \
                    --enable-cross-compile \
                    --arch="aarch64" \
                    --cpu="cortex-a53" \
                    --cc="${CROSS_COMPILE}gcc" \
                    --ar="${CROSS_COMPILE}ar" \
                    --strip="${CROSS_COMPILE}strip" \
                    --enable-rpath \
                    # options
                    --enable-shared \
                    --disable-static \
                    --disable-debug \
                    --disable-doc \
                    --enable-version3 \
                    --enable-libdrm \
                    --enable-rkmpp \
                    --enable-libx264 \
                    --enable-nonfree \
                    --enable-gpl \
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
    && make install

RUN set -x \
    # setting-up permissions for realsense devices
    && mkdir -p "${ROOTFS}/etc/udev/rules.d/" \
    && cp "librealsense/config/99-realsense-libusb.rules" "${ROOTFS}/etc/udev/rules.d/"


# sdl
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/sdl.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "sdl" \
    # rk3399 hdmi output
    && sed -i "s:DRM_MODE_CONNECTED:DRM_MODE_CONNECTED \&\& conn->connector_type == DRM_MODE_CONNECTOR_HDMIA:" "./src/video/kmsdrm/SDL_kmsdrmvideo.c" \
    && mkdir "build" && cd "build" \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSDL_STATIC=OFF \
                .. \
    && make -j$(nproc) \
    && make install \
    # for cross-compile
    && cp ${PREFIX}/bin/sdl2-config /usr/local/bin/



###############
# application #
###############

# gdb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gdb.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "gdb" \
    && mkdir "build" && cd "build" \
    && ../configure --host="x86_64-linux-gnu" \
                    --target="${HOST}" \
    && make -j$(nproc)

RUN set -x \
    && cd "gdb/gdb/gdbserver" \
    && ./configure  --host="${HOST}" \
                    --target="${HOST}" \
    && make -j$(nproc)

RUN set -x \
    # gdb(host)
    && cp "gdb/build/gdb/gdb" "${PREFIX}/"  \
    && x86_64-linux-gnu-strip --strip-unneeded "${PREFIX}/gdb" \
    # gdbserver(target)
    && cp "gdb/gdb/gdbserver/gdbserver" "${ROOTFS}/usr/bin/" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/usr/bin/gdbserver"


# mpv
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpv.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "mpv" \
    && ./bootstrap.py \
    && ./waf configure  CC=${CROSS_COMPILE}gcc \
                        CFLAGS="-I${PREFIX}/include" \
                        LDFLAGS="-L${PREFIX}/lib" \
                        --prefix="${PREFIX}" \
                        --enable-libmpv-shared \
                        --enable-egl-drm \
                        --enable-sdl2 \
                        --disable-lua \
                        --disable-javascript \
                        --disable-libass \
    && ./waf build -j$(nproc) \
    && ./waf install

RUN set -x \
    && aarch64-linux-gnu-strip --strip-unneeded "${PREFIX}/bin/mpv"


# sdlpal
#----------------------------------------------------------------------------------------------------------------#
ADD "archives/pal.tar.gz" "${ROOTFS}/opt/"
ADD "packages/sdlpal.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "sdlpal/unix" \
    # do not link GL
    && sed -i "s:# define PAL_HAS_GLSL 1:# define PAL_HAS_GLSLx 0:" "pal_config.h" \
    && sed -i "s:LDFLAGS += -lGL -pthread:LDFLAGS += -pthread:" "Makefile" \
    # cross-compile
    && sed -i "s:HOST =:HOST = ${CROSS_COMPILE}:" "Makefile" \
    && make -j$(nproc)

RUN set -x \
    && cp "sdlpal/unix/sdlpal" "${ROOTFS}/opt/pal/" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/pal/sdlpal"



#############
# unit-test #
#############

# media
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/media/*" "${ROOTFS}/opt/"


# sdl_test
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/sdl_test.cpp" "${BUILD}/sdl_test/"
RUN set -x \
    && ${CROSS_COMPILE}g++ "${BUILD}/sdl_test/sdl_test.cpp" `sdl2-config --cflags --libs` -o "${ROOTFS}/opt/sdl_test" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/sdl_test"


# realsense_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/realsense_test.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "realsense_test" \
    && cmake    -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                . \
    && make -j$(nproc) \
    && cp "gbm-drm-gles-cube" "${ROOTFS}/opt/realsense_test" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/realsense_test"


# gl4es
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gl4es.tar.gz" "${BUILD}/"
RUN set -x \
    && cd gl4es \
    && sed -i "s:DRM_MODE_CONNECTED:DRM_MODE_CONNECTED \&\& connector->connector_type == DRM_MODE_CONNECTOR_HDMIA:" ./src/glx/gbm.c \
    && mkdir build && cd build \
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


# glmark2
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/glmark2.tar.gz" "${BUILD}/"
ENV CFLAGS="-I${PREFIX}/include"
ENV LDFLAGS="-L${PREFIX}/lib"
RUN set -x \
    && cd glmark2 \
    # avoid EGL conflict
    && mv "${PREFIX}/include/EGL" "${PREFIX}/include/EGL_mali" \
    && sed -i "s:DRM_MODE_CONNECTED == connector_->connection:DRM_MODE_CONNECTED == connector_->connection \&\& connector_->connector_type == DRM_MODE_CONNECTOR_HDMIA:" ./src/native-state-drm.cpp \
    && ./waf configure  CC=${CROSS_COMPILE}gcc \
                        CXX=${CROSS_COMPILE}g++ \
                        LDFLAGS="-L${PREFIX}/lib -lz" \
                        --no-debug \
                        --prefix="${PREFIX}" \
                        --data-path="/opt/glmark2/data" \
                        --with-flavors=drm-glesv2,drm-gl \
    && ./waf build -j$(nproc) \
    && ./waf install \
    # recovery EGL
    && mv "${PREFIX}/include/EGL_mali" "${PREFIX}/include/EGL"

RUN set -x \
    && cp -rf /opt/glmark2 ${ROOTFS}/opt/ \
    && cd "${PREFIX}/bin/" \
    && mv "glmark2-drm" "glmark2-es2-drm" ${ROOTFS}/opt/glmark2/ \
    && cd ${ROOTFS}/opt/glmark2/ \
    && aarch64-linux-gnu-strip --strip-unneeded "glmark2-drm" "glmark2-es2-drm"



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


# overlay
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/rootfs/" "${ROOTFS}/"


# strip so
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    && cp -rfp ${PREFIX}/lib/*.so* "${ROOTFS}/usr/lib/" \
    && find ${ROOTFS}/usr/lib -name \*.so | xargs ${CROSS_COMPILE}strip --strip-unneeded


# copy bind
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    # copy utils
    && cp /${PREFIX}/bin/* "${ROOTFS}/usr/bin/" \
    && cp /${PREFIX}/sbin/* "${ROOTFS}/usr/sbin/"


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO="/root/distro"
ENV DEVKIT="/root/devkit"
WORKDIR "/root/scripts"
