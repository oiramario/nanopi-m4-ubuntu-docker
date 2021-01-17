# Functions:
# pack_resource_image
#set -x

source functions/common.sh


pack_resource_image()
{
    # resource
    echo
   	info_msg "resource"
    local resource_img=${DISTRO}/resource.img
    [ -f ${resource_img} ] && rm -f ${resource_img}
    ${BUILD}/rkbin/tools/resource_tool --pack --verbose --image=${DISTRO}/resource.img \
        ${HOME}/scripts/boot/logo.bmp \
        ${HOME}/scripts/boot/logo_kernel.bmp \
        ${BUILD}/kernel/arch/arm64/boot/dts/rockchip/rk3399-nanopi-m4.dtb
}
