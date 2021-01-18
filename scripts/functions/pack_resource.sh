# Functions:
# pack_resource_image
#set -x

source functions/common.sh


pack_resource_image()
{
    # resource.img
    echo
   	info_msg "resource.img"
    ${BUILD}/kernel/scripts/resource_tool \
        --pack \
        --image=${DISTRO}/resource.img \
        --dtbname ${BUILD}/kernel/arch/arm64/boot/dts/rockchip/rk3399-nanopi4-rev*.dtb ${HOME}/scripts/boot/logo.bmp ${HOME}/scripts/boot/logo_kernel.bmp
}
