#######################################
# configure cross-compile environment #
#######################################

FROM ubuntu:focal
LABEL author="oiramario" \
      version="0.5.0" \
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
    # enable rga
    && sed -i '/&rga/{ n; s/disabled/okay/; }' ./arch/arm64/boot/dts/rockchip/rk3399-nanopi4-common.dtsi \
    # make
    && make nanopi4_linux_defconfig \
    && make -j$(nproc)

# ubuntu rootfs
ENV ROOTFS="${BUILD}/rootfs"
ADD "packages/ubuntu-rootfs.tar.gz" "${ROOTFS}/"

RUN set -x \
    && cd kernel \
    && make INSTALL_MOD_PATH=${ROOTFS} INSTALL_MOD_STRIP=1 modules_install \
    && KREL=`make kernelrelease` \
    # useless
    && rm -rf "${ROOTFS}/lib/modules/$KREL/kernel/drivers/gpu/arm/mali400/" \
    && rm -rf "${ROOTFS}/lib/modules/$KREL/kernel/drivers/net/wireless/rockchip_wlan"


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
    && make CONFIG_PREFIX="${BUILD}/initramfs" install

# init
COPY "archives/initramfs/*" "${BUILD}/initramfs/"
RUN set -x \
    && rm -f "linuxrc"


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
    && cp -rf overlay-firmware/lib "${ROOTFS}/usr/" \
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
    && make install

RUN set -x \
    # for cross-compile
    && cp -f /lib/pkgconfig/libudev.pc ${PKG_CONFIG_PATH}/ \
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

# libdrm
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/libdrm.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "libdrm" \
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
    && cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
                -DTARGET_SOC=rk3399 \
                -DDP_FEATURE=gbm \
                . \
    && make install

RUN set -x \
    # create gbm symlink
    && cd "${PREFIX}/lib" \
    && ln -s "libMali.so" "libgbm.so" \
    # OpenCL
    && mv ${PREFIX}/etc/OpenCL ${ROOTFS}/etc/


# alsa-lib
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/alsa-lib.tar.gz" "${BUILD}/"
RUN set -x \
    && cd "alsa-lib" \
    && autoreconf -vfi \
    && ./configure  --prefix="${PREFIX}" \
                    --host="${HOST}" \
                    --enable-shared \
                    --with-configdir=/usr/share/alsa \
    && make -j$(nproc) \
    && make install

RUN set -x \
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

RUN set -x \
    # create mpp/vpu symlink
    && cd "${PREFIX}/lib" \
    && ln -s "librockchip_mpp.so" "libmpp.so" \
    && ln -s "librockchip_vpu.so" "libvpu.so" \
    # mpp/vpu pkgconfig
    && cd "pkgconfig" \
    && cp rockchip_mpp.pc mpp.pc \
    && cp rockchip_vpu.pc vpu.pc


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
                    --enable-nonfree \
                    --enable-gpl \
    && make -j$(nproc) \
    && make install


# librealsense
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/librealsense.tar.gz" "${BUILD}/"
COPY "patch/librealsense" "$BUILD/patch/librealsense"
RUN set -x \
    && cd "librealsense" \
    # gcc9-no-Werror
    && PATCH="$BUILD/patch/librealsense" \
    && for i in `ls $PATCH`; do echo "--patch: ${i}"; patch --verbose -p1 < $PATCH/$i; done \
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
                # no wrappers
                -DBUILD_WRAPPERS=OFF \
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
    && mkdir "build" && cd "build" \
    && CFLAGS="-I${PREFIX}/include" \
       LDFLAGS="-L${PREFIX}/lib" \
       cmake    -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
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
    && gcc -v \
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
    && aarch64-linux-gnu-strip --strip-unneeded "${PREFIX}/bin/mpv" \
    && mv ${PREFIX}/etc/mpv ${ROOTFS}/etc/


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
COPY "archives/sdl_video_test.cpp" "${BUILD}/sdl_test/"
RUN set -x \
    && ${CROSS_COMPILE}g++ "${BUILD}/sdl_test/sdl_video_test.cpp" `sdl2-config --cflags --libs` -o "${ROOTFS}/opt/sdl_video_test" \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/sdl_video_test"


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
RUN set -x \
    && cd glmark2 \
    # avoid EGL conflict
    && mv "${PREFIX}/include/EGL" "${PREFIX}/include/EGL_mali" \
    && ./waf configure  CC=${CROSS_COMPILE}gcc \
                        CXX=${CROSS_COMPILE}g++ \
                        CFLAGS="-I${PREFIX}/include" \
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


# mpp_test
#----------------------------------------------------------------------------------------------------------------#
ADD "packages/mpp_test.tar.gz" "${BUILD}/"
RUN set -x \
    && cd mpp_test \
    && sed -i "s:/dev/v4l/by-path/platform-ff680000.rga-video-index0:/dev/v4l/by-path/platform-ff910000.rkisp1-video-index0:" "rkrga/RGA.h" \
    && mkdir build && cd build \
    && CFLAGS="-I${PREFIX}/include -I${PREFIX}/include/libdrm -I${PREFIX}/include/rockchip" \
       CXXFLAGS="-I${PREFIX}/include -I${PREFIX}/include/libdrm -I${PREFIX}/include/rockchip -DSZ_4K=0x00001000" \
       LDFLAGS="-L${PREFIX}/lib" \
       cmake    -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX} \
                -DCMAKE_TOOLCHAIN_FILE="${BUILD}/toolchain.cmake" \
                -DCMAKE_BUILD_TYPE=Release \
                .. \
    && make -j$(nproc)

RUN set -x \
    && mkdir -p ${ROOTFS}/opt/mpp_test/bin ${ROOTFS}/opt/mpp_test/res \
    && cp mpp_test/res/Tennis1080p.h264 ${ROOTFS}/opt/mpp_test/res/ \
    && cp mpp_test/build/mpp_linux_demo ${ROOTFS}/opt/mpp_test/bin/mpp_test \
    && aarch64-linux-gnu-strip --strip-unneeded "${ROOTFS}/opt/mpp_test/bin/mpp_test"


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


# copy bind
#----------------------------------------------------------------------------------------------------------------#
RUN set -x \
    # copy utils
    && cd ${PREFIX}/bin \
    && for f in `find ./ -executable -type f`; do xargs ${CROSS_COMPILE}strip --strip-unneeded $f; done \
    && cp -rfp ${PREFIX}/bin/* "${ROOTFS}/usr/bin/"

# overlay
#----------------------------------------------------------------------------------------------------------------#
COPY "archives/rootfs/" "${ROOTFS}/"


# ready to make
#----------------------------------------------------------------------------------------------------------------#
ENV DISTRO="/root/distro"
ENV DEVKIT="/root/devkit"
WORKDIR "/root/scripts"
