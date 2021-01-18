NanoPi4-ubuntu-docker
=====================

<p align="center"><img src="shot.jpg"/></p>

Build minimal image(<600M) for NanoPi4
OS Image for development with the following tidbits:

* rk3399_loader.bin
* idbloader.img
* resource.img
* uboot.img
* trust.img
* boot.img
* rootfs.img

# Build

To build and use the docker stuff, do the following:

* update.sh

        download or update dependencies, and make packages for docker.

* build.sh

        using aarch64 gcc-9.3 to cross-compile u-boot, kernel, rockchip stuff, libraries.
        option:
            NoApp=1       --- without app
            NoTest=1      --- without test

* run.sh

        running the prepared environment for making images.

* make.sh

        make images.
        usage:
            make.sh res       --- pack resource.img
            make.sh loader    --- pack loader images
            make.sh boot      --- pack boot.img
            make.sh rootfs    --- pack rootfs.img
            make.sh all       --- pack all above
            make.sh devkit    --- use /opt/devkit for cross-compile or debugging

* clean.sh

        clean files by make.sh.
        usage:
            clean.sh distro
            clean.sh devkit
            clean.sh docker
            clean.sh packages
            clean.sh all

* fusing.sh

        fusing images to emmc.
        usage:
            fusing.sh loader
            fusing.sh res
            fusing.sh boot
            fusing.sh rootfs
            fusing.sh all

# Rootfs

### runtime

- eudev
- libdrm
- libmali
- librga
- alsa
- mpp
- libusb
- zlib
- libjpeg
- libpng
- ffmpeg
- librealsense
- sdl2
- gdbserver
- gl4es

### application

- mpv
- sdlpal
- glmark2

### unit-test

- rga_test
- sdl_test
- opencl_test
- realsense_test
