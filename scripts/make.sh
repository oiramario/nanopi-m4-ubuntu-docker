#!/bin/bash
#set -x

## Functions
source functions/common.sh
source functions/loader.sh
source functions/boot.sh
source functions/rootfs.sh

help()
{
	echo
	info_msg "Usage:"
	info_msg "	make.sh [target]"
	echo
	info_msg "Example:"
	info_msg "	make.sh loader    --- pack loaders image"
	info_msg "	make.sh boot      --- pack boot.img"
	info_msg "	make.sh rootfs    --- pack rootfs.img"
	info_msg "	make.sh all       --- pack all above"
	echo
}


######################################################################################
TARGET="$1"
case "$TARGET" in
	loader)
		pack_loader_image
		;;
	boot)
		pack_boot_image
		;;
	rootfs)
		pack_rootfs_image
		;;
	all)
		pack_loader_image
		pack_boot_image
		pack_rootfs_image
		;;
	*)
		error_msg "Unsupported target: $TARGET"
		help
		exit -1
		;;
esac

echo
info_msg "Done."
ls ${DISTRO} -lh
