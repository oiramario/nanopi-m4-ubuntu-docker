# configure
#----------------------------------------------------------------------------------------------------------------#
FROM ubuntu:bionic
LABEL author="oiramario" \
      version="0.3.0" \
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
        patch  make  gcc-aarch64-linux-gnu  g++-aarch64-linux-gnu  pkg-config  cmake \
        # u-boot
        bison  flex \
        # kernel
        bc  libssl-dev  kmod \
        # gdb
        texinfo \
        # libdrm
        autoconf  xutils-dev  libtool  libpciaccess-dev \
        # eudev
        gperf \
        # initramfs
        cpio \
        # FIT(Flattened Image Tree)
        device-tree-compiler \
        # boot.img
        genext2fs \
        # rootfs
        binfmt-support  qemu-user-static \
        # mpv
        python \
        # alsa-utils
        autopoint  libncurses5-dev \
        # local:en_US.UTF-8
        locales \
    && locale-gen en_US.UTF-8


# setup build environment
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8' \
    TERM=screen \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    ARCH="arm64" \
    HOST="aarch64-linux-gnu" \
    BUILD="/root/build"

USER root

WORKDIR ${BUILD}


# u-boot
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/u-boot.tar.gz" "${BUILD}/"
RUN set -x \
    && cd u-boot \
    # make
    && make rk3399_defconfig \
    && make -j$(nproc)


# kernel
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/kernel.tar.gz" "${BUILD}/"
RUN set -x \
    && cd kernel \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)


# busybox
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/busybox.tar.gz" "${BUILD}/"
RUN set -x \
    && cd busybox \
    # make
    && make defconfig \
    # static link
    && sed -i "s:# CONFIG_STATIC is not set:CONFIG_STATIC=y:" .config \
    && make -j$(nproc) \
    && make CONFIG_PREFIX=${BUILD}/initramfs install

# overlay
COPY "overlays/initramfs/*" "${BUILD}/initramfs/"


# ubuntu rootfs
#----------------------------------------------------------------------------------------------------------------#
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"


# compile settings
#----------------------------------------------------------------------------------------------------------------#
ENV PREFIX=/opt/devkit
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV CFLAGS="-I${PREFIX}/include"
ENV LDFLAGS="-L${PREFIX}/lib"
COPY "toolchain.cmake" "${BUILD}/"
RUN mkdir -p ${PREFIX}


# libmali
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libmali.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libmali \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DTARGET_SOC=rk3399 \
                -DDP_FEATURE=gbm \
                . \
    && make install


# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd libdrm \
    && ./autogen.sh --prefix=${PREFIX} --host=${HOST} \
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


# mpp
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpp.tar.gz" "${BUILD}/"
RUN set -x \
    && cd mpp \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DENABLE_SHARED=ON \
                -DENABLE_STATIC=OFF \
                -DHAVE_DRM=ON \
                . \
    && make -j$(nproc) \
    && make install


# ffmpeg
#----------------------------------------------------------------------------------------------------------------#
# x264
ADD "packages/x264.tar.gz" "${BUILD}/"
RUN set -x \
    && cd x264 \
    && ./configure  --prefix=${PREFIX} \
                    --host=${HOST} \
                    --cross-prefix=${CROSS_COMPILE} \
                    --enable-shared \
                    --disable-asm \
                    --disable-opencl \
    && make -j$(nproc) \
    && make install


# ffmpeg
ADD "packages/ffmpeg.tar.gz" "${BUILD}/"
RUN set -x \
    && cd ffmpeg \
    && ./configure  --prefix=${PREFIX} \
                    --target-os=linux \
                    --arch="aarch64" \
                    --cpu="cortex-a53" \
                    --enable-cross-compile \
                    --cc=aarch64-linux-gnu-gcc \
                    --ar=aarch64-linux-gnu-ar \
                    --strip=aarch64-linux-gnu-strip \
                    --enable-rpath \
                    # options
                    --enable-shared \
                    --disable-static \
                    --disable-debug \
                    --enable-version3 \
                    --enable-libdrm \
                    --enable-rkmpp \
                    --enable-libx264 \
                    --enable-nonfree \
                    --enable-gpl \
                    --disable-doc \
    && make -j$(nproc) \
    && make install


# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd alsa-lib \
    && autoreconf -vfi \
    && ./configure  --prefix=${PREFIX} \
                    --host=${HOST} \
                    --disable-python \
                    --enable-shared \
    && make -j$(nproc) \
    && make install


# mpv
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpv.tar.gz" "${BUILD}/"
RUN set -x \
    && cd mpv \
    && ./bootstrap.py \
    && CC=aarch64-linux-gnu-gcc \
       AR=aarch64-linux-gnu-ar \
       ./waf configure  --prefix=${PREFIX} \
                        --enable-libmpv-shared \
                        --enable-egl-drm \
                        --disable-lua \
                        --disable-javascript \
                        --disable-libass \
                        --disable-zlib \
    && ./waf build -j$(nproc) \
    && ./waf install


# gdb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gdb.tar.gz" "${BUILD}/"
RUN set -x \
    && cd gdb \
    && mkdir build && cd build \
    && ../configure --host=x86_64-linux-gnu --target=${HOST} \
    && make -j$(nproc)

RUN set -x \
    && cd gdb/gdb/gdbserver \
    && ./configure --host=${HOST} --target=${HOST} \
    && make -j$(nproc)

RUN set -x \
    # gdb(host)
    && cp gdb/build/gdb/gdb ${PREFIX}/  \
    && x86_64-linux-gnu-strip --strip-unneeded ${PREFIX}/gdb \
    # gdbserver(target)
    && cp gdb/gdb/gdbserver/gdbserver ${ROOTFS}/usr/bin/ \
    && aarch64-linux-gnu-strip --strip-unneeded ${ROOTFS}/usr/bin/gdbserver


# libusb
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libusb.tar.gz" "${BUILD}/"
RUN set -x \ 
    && cd libusb \
    && autoreconf -vfi \
    && ./configure  --prefix=${PREFIX} --host=${HOST} \
                    --disable-udev \
    && make -j$(nproc) \
    && make install


# librealsense
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librealsense.tar.gz" "${BUILD}/"
RUN set -x \
    && cd librealsense \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DCMAKE_TOOLCHAIN_FILE=${BUILD}/toolchain.cmake \
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
    && mkdir -p ${ROOTFS}/etc/udev/rules.d/ \
    && cp librealsense/config/99-realsense-libusb.rules ${ROOTFS}/etc/udev/rules.d/


# gbm-drm-gles-cube
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/ogles-cube.tar.gz" "${BUILD}/"
RUN set -x \
    && cd ogles-cube \
    && cmake -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
    && make -j$(nproc) \
    && cp ./gbm-drm-gles-cube ${ROOTFS}/opt/ \
    && aarch64-linux-gnu-strip --strip-unneeded ${ROOTFS}/opt/gbm-drm-gles-cube


# rockchip materials
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/rkbin.tar.gz" "${BUILD}/"
ADD "packages/rk-rootfs-build.tar.gz" "${BUILD}/"
RUN set -x \
    && cd rk-rootfs-build \
    # rockchip firmware
    && cp -rf overlay-firmware/* ${ROOTFS}/ \
    && cd ${ROOTFS}/usr/bin/ \
    # choose 64bits
    && mv -f brcm_patchram_plus1_64 brcm_patchram_plus1 \
    && mv -f rk_wifi_init_64 rk_wifi_init \
    && rm -f brcm_patchram_plus1_32 rk_wifi_init_32 \
    # remove useless
    && rm -f npu* upgrade_tool \
    # bt, wifi, audio firmware
    && mkdir -p ${ROOTFS}/system/lib/modules/ \
    && find ${BUILD}/kernel/drivers/net/wireless/rockchip_wlan -name "*.ko" | \
        xargs -n1 -i cp {} ${ROOTFS}/system/lib/modules/ \
    # power manager
    && cd ${BUILD}/rk-rootfs-build/overlay/etc/Powermanager \
    && cp triggerhappy.service ${ROOTFS}/lib/systemd/system/ \
    && cp power-key.sh ${ROOTFS}/usr/bin/ \
    && mkdir -p ${ROOTFS}/etc/triggerhappy/triggers.d/ \
    && cp power-key.conf ${ROOTFS}/etc/triggerhappy/triggers.d/ \
    && cp triggerhappy ${ROOTFS}/etc/init.d/ \
    # udev rules
    && cd ${BUILD}/rk-rootfs-build/overlay/etc/udev/rules.d \
    && mkdir -p ${ROOTFS}/etc/udev/rules.d/ \
    && cp 50-hevc-rk3399.rules \
          50-mail.rules \
          50-vpu-rk3399.rules \
          60-media.rules \
          60-drm.rules \
          ${ROOTFS}/etc/udev/rules.d/ \
    && cp ${BUILD}/rk-rootfs-build/overlay/usr/local/bin/drm-hotplug.sh ${ROOTFS}/usr/local/bin/ \
    # gst environment variables
    && mkdir -p ${ROOTFS}/etc/profile.d/ \
    && cp ${BUILD}/rk-rootfs-build/overlay/etc/profile.d/gst.sh ${ROOTFS}/etc/profile.d/


# gl4es
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/gl4es.tar.gz" "${BUILD}/"
RUN set -x \
    && cd gl4es \
    && rm -f ./include/EGL/eglplatform.h \
    && sed -i "s?DRM_MODE_CONNECTED?DRM_MODE_CONNECTED \&\& connector->connector_type == DRM_MODE_CONNECTOR_HDMIA?" ./src/glx/gbm.c \
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DNOX11=ON \
                -DGBM=ON \
                -DDEFAULT_ES=2 \
                -DUSE_CLOCK=ON \
                .. \
    && make -j$(nproc)

RUN set -x \
    && cd gl4es/build \
    && cp lib/libGL.so.1 ${PREFIX}/lib/ \
    && cd ${PREFIX}/lib \
    && ln -s libGL.so.1 libGL.so


# sdl
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/sdl.tar.gz" "${BUILD}/"
RUN set -x \
    && cd sdl \
    && mkdir build && cd build \
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                -DSDL_STATIC=OFF \
                .. \
    && make -j$(nproc) \
    && make install

# for cross-compile
RUN set -x \
    && cp ${PREFIX}/bin/sdl2-config /usr/local/bin/


# sdlpal
#----------------------------------------------------------------------------------------------------------------#
RUN apt-get install -y git
ADD "packages/sdlpal.tar.gz" "${BUILD}/"
RUN set -x \
    && cd sdlpal/unix \
    && sed -i "s:HOST =:HOST = ${CROSS_COMPILE}:" Makefile \
    && sed -i "s?LDFLAGS += -lGL -pthread?LDFLAGS += -lGL -ldrm -pthread -L/opt/devkit/lib -Wl,-rpath,/opt/devkit/lib?" Makefile \
    && make -j$(nproc)

# copy for test
RUN set -x \
    && mkdir -p ${ROOTFS}/opt/test \
    && cp sdlpal/unix/sdlpal ${ROOTFS}/opt/test/


# for cross-compile
RUN set -x \
    && cp ${PREFIX}/bin/sdl2-config /usr/local/bin/


# k380 keyboard
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/k380-function-keys-conf.tar.gz" "${BUILD}/"
RUN set -x \
    && cd k380-function-keys-conf \
    && make -j$(nproc) \
    && DESTDIR=${ROOTFS} make install


# overlay
#----------------------------------------------------------------------------------------------------------------#
COPY "overlays/rootfs/" "${ROOTFS}/"


# strip so
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    && cp -rfp ${PREFIX}/lib/*.so* ${ROOTFS}/usr/lib/ \
    && find ${ROOTFS}/usr/lib/ -name \*.so | xargs aarch64-linux-gnu-strip --strip-unneeded


# copy bind
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    # copy utils
    && cp /opt/devkit/bin/* ${ROOTFS}/usr/bin/


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO=/root/distro
ENV DEVKIT=/root/devkit

WORKDIR /root/scripts
