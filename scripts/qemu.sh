#!/bin/bash
#set -x


#    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
#    -kernel ${DISTRO}/Image \
#    -initrd ${DISTRO}/ramdisk.cpio.gz \
#    -append "root=/dev/ram rdinit=/init console=ttyAMA0"

#dd if=${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin of=/tmp/mmc.img conv=notrunc bs=1M
#dd if=${DISTRO}/boot.scr of=/tmp/mmc.img conv=notrunc bs=1M seek=2
#dd if=${DISTRO}/fitImage.itb of=/tmp/mmc.img conv=notrunc bs=1M seek=4

${BUILD}/qemu-4.0.0/aarch64-softmmu/qemu-system-aarch64 \
    -serial stdio \
    -machine virt -cpu cortex-a57 -smp 4 -m 1024 \
    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
    -drive if=none,file=/tmp/mmc.img,media=disk,id=boot \
    -device virtio-blk-device,drive=boot