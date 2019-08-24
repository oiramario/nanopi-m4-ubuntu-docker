#!/bin/bash

set -x

ROMS=~/program

if [ ! -f ${ROMS}/flash0.img ]; then
    dd if=/dev/zero of=${ROMS}/flash0.img bs=1M count=64
    dd if=${ROMS}/QEMU_EFI.fd of=${ROMS}/flash0.img conv=notrunc
    dd if=/dev/zero of=${ROMS}/flash1.img bs=1M count=64
fi

if [ ! -f ${ROMS}/hda.img ]; then
    dd if=/dev/zero of=${ROMS}/hda.img bs=1M count=8192
fi


CDROM_IMG=${ROMS}/ubuntu-18.04.1-desktop-amd64.iso
HDA_IMG=${ROMS}/hda.img
 
make_cdrom_arg()
{
  echo "-drive file=$1,id=cdrom,if=none,media=cdrom,format=raw" \
    "-device virtio-scsi-device -device scsi-cd,drive=cdrom"
}
 
make_hda_arg()
{
  echo "-drive if=none,file=$1,id=hd0,format=raw" \
    "-device virtio-blk-device,drive=hd0"
}
 
HDA_ARGS=`make_hda_arg $HDA_IMG`
if [ $# -eq 1 ]; then
  case $1 in
    install)
      CDROM_ARGS=`make_cdrom_arg $CDROM_IMG`
      ;;
    *)
      CDROM_ARGS=""
      ;;
  esac
fi
 
qemu-system-aarch64 -m 1024 -cpu cortex-a57 -M virt,accel=kvm \
    -monitor none -serial stdio -no-reboot -nographic \
    -bios ${ROMS}/QEMU_EFI.fd \
    $CDROM_ARGS \
    $HDA_ARGS
