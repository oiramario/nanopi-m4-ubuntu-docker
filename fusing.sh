#!/bin/bash
#
#set -x

source ./scripts/functions/common.sh


if [ ! -d distro ]; then
    error_msg "build distro first."
    exit
fi

DISTRO_DIR=$(pwd)/distro
TOOLS_DIR=$(pwd)/tools

if [ ! -f "/etc/udev/rules.d/99-rk-rockusb.rules" ]; then
    warning_msg "add rockusb rules to udev"
    sudo cp -f ${TOOLS_DIR}/99-rk-rockusb.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi


idbloader_addr=""
idbloader_size=""

resource_addr=""
resource_size=""

uboot_addr=""
uboot_size=""

trust_addr=""
trust_size=""

boot_addr=""
boot_size=""

rootfs_addr=""
rootfs_size=""

parts=`grep 'CMDLINE: mtdparts=rk29xxnand:' ${TOOLS_DIR}/parameter.gpt`
parts=${parts#*rk29xxnand:}

OLD_IFS="$IFS" 
IFS="," 
arr=($parts) 
IFS="$OLD_IFS" 
for par in ${arr[@]} 
do 
    size=${par%%@*}
    
    tmp=${par##*@}
    addr=${tmp%%(*}

    name=${tmp##*(}
    name=${name%%)*}
    name=${name%%:*}

    case $name in
        idbloader)
            idbloader_addr=${addr}
            idbloader_size=${size}
            ;;
        resource)
            resource_addr=${addr}
            resource_size=${size}
            ;;
        uboot)
            uboot_addr=${addr}
            uboot_size=${size}
            ;;
        trust)
            trust_addr=${addr}
            trust_size=${size}
            ;;
        boot)
            boot_addr=${addr}
            boot_size=${size}
            ;;
        rootfs)
            rootfs_addr=${addr}
            rootfs_size=${size}
            ;;
        reserved1)
            ;;
        reserved2)
            ;;
        *)
            error_msg "Unknown format."
            exit -1
            ;;
    esac
done


fusing_begin()
{
    ${TOOLS_DIR}/rkdeveloptool  db  ${DISTRO_DIR}/rk3399_loader.bin
    sleep 2
    ${TOOLS_DIR}/rkdeveloptool  ul  ${DISTRO_DIR}/rk3399_loader.bin
    sleep 2
    ${TOOLS_DIR}/rkdeveloptool  gpt ${TOOLS_DIR}/parameter.gpt
    sleep 2
}


fusing_end()
{
    ${TOOLS_DIR}/rkdeveloptool rd
}


fusing_idbloader()
{
    local name="idbloader"
    local addr=${idbloader_addr}
    local size=${idbloader_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


fusing_resource()
{
    local name="resource"
    local addr=${resource_addr}
    local size=${resource_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


fusing_uboot()
{
    local name="uboot"
    local addr=${uboot_addr}
    local size=${uboot_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


fusing_trust()
{
    local name="trust"
    local addr=${trust_addr}
    local size=${trust_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


fusing_boot()
{
    local name="boot"
    local addr=${boot_addr}
    local size=${boot_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


fusing_rootfs()
{
    local name="rootfs"
    local addr=${rootfs_addr}
    local size=${rootfs_size}
    info_msg "${name}"
    ${TOOLS_DIR}/rkdeveloptool wl ${addr} ${DISTRO_DIR}/${name}.img
    sleep 1
}


help()
{
	echo
	info_msg "Usage:"
	info_msg "	fusing.sh [target]"
	echo
	info_msg "Example:"
	info_msg "	fusing.sh loader"
	info_msg "	fusing.sh resource"
	info_msg "	fusing.sh boot"
	info_msg "	fusing.sh rootfs"
	info_msg "	fusing.sh all"
	echo
}


######################################################################################
TARGET="$1"
case "$TARGET" in
	loader)
        fusing_begin
            fusing_idbloader
            fusing_uboot
            fusing_trust
        fusing_end
		;;
	resource)
        fusing_begin
            fusing_resource
        fusing_end
		;;
	boot)
        fusing_begin
            fusing_boot
        fusing_end
		;;
	rootfs)
        fusing_begin
            fusing_rootfs
        fusing_end
		;;
	all)
        fusing_begin
            fusing_idbloader
            fusing_resource
            fusing_uboot
            fusing_trust
            fusing_boot
            fusing_rootfs
        fusing_end
		;;
	*)
		error_msg "Unsupported target: $TARGET"
		help
		exit -1
		;;
esac
