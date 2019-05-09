#!/bin/bash
#set -x

## Functions
source archives/functions/common-functions
source archives/functions/build-loader
source archives/functions/build-boot

help()
{
	echo
	info_msg "Usage:"
	info_msg "	./build.sh [target]"
	info_msg
	info_msg "Example:"
	info_msg
	info_msg "	./build.sh loader    --- pack loaders image"
	info_msg "	./build.sh boot      --- pack boot.img"
	info_msg "	./build.sh rootfs    --- pack rootfs.img"
	info_msg "	./build.sh all       --- pack all above"
	echo
}


######################################################################################
TARGET="$1"

if [ "$TARGET" != "loader" ] && [ "$TARGET" != "boot" ] && [ "$TARGET" != "rootfs" ]; then
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
esac

ls ${DISTRO} -lh
echo -e "\nDone."
echo -e "\n`date`"
