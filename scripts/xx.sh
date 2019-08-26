#!/bin/bash

set -x

ROMS=${DISTRO}

if [ ! -f ${ROMS}/flash0.img ]; then
    dd if=/dev/zero of=${ROMS}/flash0.img bs=1M count=64
    dd if=${ROMS}/QEMU_EFI.fd of=${ROMS}/flash0.img conv=notrunc
    dd if=/dev/zero of=${ROMS}/flash1.img bs=1M count=64
fi

if [ ! -f ${ROMS}/hda.img ]; then
    #dd if=/dev/zero of=${ROMS}/hda.img bs=1M count=4096
    qemu-img create -f qcow2 ${ROMS}/hda.qcow2 4G 
fi


CDROM_IMG=${ROMS}/ubuntu-18.04.3-server-amd64.iso
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
CDROM_ARGS=`make_cdrom_arg $CDROM_IMG`
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
 
qemu-system-x86_64 -m 4G -cpu host -enable-kvm \
    -monitor none -serial stdio -no-reboot -nographic \
    -cdrom $CDROM_IMG \
    -hda ${ROMS}/hda.qcow2
