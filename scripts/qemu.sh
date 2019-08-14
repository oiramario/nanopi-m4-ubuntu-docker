#!/bin/bash
#set -x


#    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
#    -kernel ${DISTRO}/Image \
#    -initrd ${DISTRO}/ramdisk.cpio.gz \
#    -append "root=/dev/ram rdinit=/init console=ttyAMA0"

${BUILD}/qemu-4.0.0/aarch64-softmmu/qemu-system-aarch64 \
    -serial stdio -no-reboot \
    -machine virt -cpu cortex-a57 -smp 4 -m 1024 \
    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
    -drive if=ide,file=/tmp/qemu_boot.img,media=disk,id=boot \
    -device virtio-blk-device,drive=boot
