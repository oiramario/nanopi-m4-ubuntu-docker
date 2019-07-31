#!/bin/bash
#set -x

## Functions
source functions/common-functions.sh
source functions/build-loader.sh
source functions/build-boot.sh
source functions/build-rootfs.sh

help()
{
	echo
	info_msg "Usage:"
	info_msg "	build.sh [target]"
	echo
	info_msg "Example:"
	info_msg "	build.sh loader    --- pack loaders image"
	info_msg "	build.sh boot      --- pack boot.img"
	info_msg "	build.sh rootfs    --- pack rootfs.img"
	info_msg "	build.sh all       --- pack all above"
	echo
}


######################################################################################
TARGET="$1"

if [ "$TARGET" != "loader" ] && 
   [ "$TARGET" != "boot" ] && 
   [ "$TARGET" != "rootfs" ] && 
   [ "$TARGET" != "all" ]; then
	error_msg "Unsupported target: $TARGET"
	help
	exit -1
fi


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
esac

echo
info_msg "Done."
ls ${DISTRO} -lh
