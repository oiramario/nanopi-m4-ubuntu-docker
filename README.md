NanoPi4-ubuntu-docker
=====================

<p align="center"><img src="shot.jpg"/></p>

Build minimal image(<600M) for NanoPi-M4
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

# Loader

* rk3399_loader.bin

        boot_merger pack RK3399MINIALL.ini

* idbloader.img

        mkimage -T rksd -n rk3399 -d rk3399_ddr_800MHz.bin idbloader.img
        cat rk3399_miniloader.bin >> idbloader.img

* resource.img

        resource_tool --pack --verbose --image=resource.img logo.bmp logo_kernel.bmp rk3399-nanopi-m4.dtb

* uboot.img

        loaderimage --pack --uboot u-boot-dtb uboot.img 0x00200000

* trust.img

        trust_merger --pack RKTRUST/RK3399TRUST.ini

# OS

* kernel

        description = "nanopi-m4 boot uImage";

        images {
                kernel { ... };

                fdt_m4 { ... };

                initramfs { ... };
        };

        configurations {
                default = "conf_m4";

                conf_m4 { ... };
        };

* busybox

        find . | cpio -oH newc | gzip > ramdisk.cpio.gz

* ubuntu

        ubuntu-base-20.04-base-arm64

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
