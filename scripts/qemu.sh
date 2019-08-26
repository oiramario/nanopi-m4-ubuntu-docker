#!/bin/bash
#set -x


#    -bios ${BUILD}/qemu-4.0.0/roms/u-boot/u-boot.bin \
#    -kernel ${DISTRO}/Image \
#    -initrd ${DISTRO}/ramdisk.cpio.gz \
#    -append "root=/dev/ram rdinit=/init console=ttyAMA0"

#    -bios ${DISTRO}/qemu-u-boot.bin \
#    -drive if=none,file=${DISTRO}/qemu-boot.img,media=disk,id=boot \
#    -device virtio-blk-device,drive=boot

#    -fsdev local,security_model=passthrough,id=fsdev0,path=/tmp/share \
#    -device virtio-9p-pci,fsdev=fsdev0,mount_tag=host_folder

#    -enable-kvm 
#    -pflash /tmp/flash0.img -pflash /tmp/flash1.img \

mkdir -p /tmp/share

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 -smp 4 \
    -machine type=virt \
    -m 4G \
    -monitor none -serial stdio -no-reboot -nographic \
    -bios ${DISTRO}/qemu-u-boot.bin \
    -drive if=none,file=${DISTRO}/qemu-boot.img,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0