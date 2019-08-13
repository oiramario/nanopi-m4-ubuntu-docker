#!/bin/bash
#set -x

${BUILD}/qemu-4.0.0/aarch64-softmmu/qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 -smp 4 -m 4096 \
    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
    -device loader,file=${DISTRO}/Image,addr=0x00080000 \
    -nographic -no-reboot
#    -bios ${BUILD}/QEMU_EFI.fd \
#    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
#    -kernel ${DISTRO}/Image \
#    -initrd ${DISTRO}/ramdisk.cpio.gz \
#    -append "root=/dev/ram rdinit=/init console=ttyAMA0"
