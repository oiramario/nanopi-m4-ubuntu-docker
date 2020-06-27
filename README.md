NanoPi4-docker
================

Build minimal image for NanoPi-M4 / T4 / NEO4
OS Image for development with the following tidbits:

* MiniLoaderAll.bin
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

    using aarch65 gcc-9.3 to cross-compile u-boot, kernel, rockchip stuff, libraries.

* run.sh

    running the prepared environment for making images.

* make.sh

    Usage:
        make.sh [target]"
            make.sh loader    --- pack loader images"
            make.sh boot      --- pack boot.img"
            make.sh rootfs    --- pack rootfs.img"
            make.sh devkit    --- pack development kit"
            make.sh all       --- pack all above"

* clean.sh

    clean all intermediate files.

# Loader

* MiniLoaderAll.bin

    boot_merger RK3399MINIALL.ini

* idbloader.img

    mkimage -T rksd -n rk3399 -d rk3399_ddr_800MHz.bin idbloader.img
    cat rk3399_miniloader.bin >> idbloader.img

* resource.img

    resource_tool --pack --verbose --image=resource.img logo.bmp logo_kernel.bmp rk3399-nanopi4.dtb

* uboot.img

    loaderimage --pack --uboot u-boot.bin uboot.img 0x00200000

* trust.img

    trust_merger RKTRUST/RK3399TRUST.ini

# OS

* kernel

    description = "U-Boot fitImage for rk3399_aarch64 kernel";
    #address-cells = <1>;
  
    images {
	kernel {
            description = "kernel 4.4.y";
            data = /incbin/("./kernel.gz");
            type = "kernel";
            arch = "arm64";
            os = "linux";
			compression = "gzip";
			load = <0x02080000>;
			entry = <0x02080000>;
			hash_crc {
				algo = "crc32";
			};
		};

        fdt_m4 {
            description = "nanopi-m4";
            data = /incbin/("./rk3399-nanopi4-rev01.dtb");
            type = "flat_dt";
            arch = "arm64";
			compression = "none";
			load = <0x01f00000>;
			hash_crc {
				algo = "crc32";
			};
        };

        initramfs {
            description = "busybox";
            data = /incbin/("./ramdisk.cpio.gz");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
			compression = "gzip";
			load = <0x06000000>;
			entry = <0x06000000>;
			hash_crc {
				algo = "crc32";
			};
        };
    };

    configurations {
        default = "conf_m4";

        conf_m4 {
            description = "nanopi-m4";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt_m4";
        };
    };

* busybox

    find . | cpio -oH newc | gzip > ramdisk.cpio.gz

* eudev

# Rootfs

### runtime

* libdrm

* libmali

* librga

* alsa

* mpp

* libusb

* zlib

* libjpeg

* libpng

* ffmpeg

* librealsense

* sdl2

* gdbserver

### application

* mpv

* sdlpal

* glmark2

### unit-test

* rga_test

* sdl_test

* opencl_test

* realsense_test
