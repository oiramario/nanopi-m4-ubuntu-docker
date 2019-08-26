#!/bin/bash
#
#set -x

source scripts/functions/common.sh


download_dir=$(pwd)/downloads
[ ! -d ${download_dir} ] && mkdir -p ${download_dir}

packages_dir=$(pwd)/packages
[ ! -d ${packages_dir} ] && mkdir -p ${packages_dir}


update_sources()
{
    cd ${download_dir}

    local gits=(
    "stable-4.4-rk3399-linux,https://github.com/rockchip-linux/rkbin.git,rkbin"
    "stable-4.4-rk3399-linux,https://github.com/rockchip-linux/u-boot.git,u-boot"
    "nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
    "master,https://github.com/rockchip-linux/rk-rootfs-build.git,rk-rootfs-build"
    )
    for i in ${gits[@]}
    do
        local str=($i)
        local arr=(${str//,/ })

        local branch=${arr[0]}
        local url=${arr[1]}
        local dir=${arr[2]}

        echo
        info_msg "checking ${dir}"
        if [ ! -d ${dir} ];then
            git clone --depth 1 --branch ${branch} --single-branch ${url} ${dir}
        else
            local ret=$(git -C ${dir} pull)
            if [ $? -eq 0 ]; then
                if [[ ${ret} =~ "Already up to date." ]];then
                    echo "up-to-date sources"
                    if [ -f ${packages_dir}/${dir}.tar.gz ]; then
                        echo "up-to-date package"
                        continue
                    fi
                fi
            else
                error_msg "operation failed"
                continue
            fi
        fi

        if [ $? -eq 0 ] ; then
            info_msg "packaging ${dir}"
            local exclude="--exclude-vcs"
            if [ ${dir} = "rk-rootfs-build" ];then
                exclude+=" \
                    --exclude=*.md \
                    --exclude=${dir}/mk-*.sh \
                    --exclude=overlay-firmware/usr/share/npu_fw \
                    --exclude=packages/armhf \
                    --exclude=packages/arm64/others \
                    --exclude=packages/arm64/video \
                    --exclude=packages/arm64/xserver \
                    --exclude=packages/arm64/libmali/libmali-rk-bifrost-*.deb \
                    --exclude=packages-patches \
                    --exclude=ubuntu-build-service"
            fi

            eval tar -czf ${packages_dir}/${dir}.tar.gz $exclude -C . ${dir}
        fi
    done
}


update_archive()
{
    cd ${download_dir}

    local tars=(
    "busybox,https://github.com/mirror/busybox/archive/1_31_0.tar.gz"
    "ubuntu-rootfs,http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz"
    "qemu,https://download.qemu.org/qemu-4.1.0.tar.xz"
    "QEMU_EFI.fd,http://snapshots.linaro.org/components/kernel/leg-virt-tianocore-edk2-upstream/latest/QEMU-AARCH64/RELEASE_GCC5/QEMU_EFI.fd"
    "librealsense,https://github.com/IntelRealSense/librealsense/archive/v2.26.0.tar.gz"
    )
    for i in ${tars[@]}
    do
        local str=($i)
        local arr=(${str//,/ })

        local name=${arr[0]}
        local url=${arr[1]}

        echo
        info_msg "checking ${name}"

        if [ ! -f ${download_dir}/${name} ]; then
            rm -rf /tmp/${name}
            wget -O /tmp/${name} ${url}
            if [ $? -eq 0 ] ; then
                cp /tmp/${name} ${download_dir}/
                # prepare to re-package
                rm -f ${packages_dir}/${name}.tar.gz
            else
                error_msg "operation failed"
                continue
            fi
        fi

        if [ $? -eq 0 ] && [ ! -f ${packages_dir}/${name}.tar.gz ]; then
            local archive="z"
            case "${name}" in
                ubuntu-rootfs)
                    # it's .tar.gz already
                    cp -v ${download_dir}/${name} ${packages_dir}/${name}.tar.gz
                    continue
                    ;;
                qemu)
                    archive="J"
                    ;;
                QEMU_EFI.fd)
                    # it's single file
                    tar -vczf ${packages_dir}/${name}.tar.gz ${name}
                    continue
                    ;;
                *)
                    ;;
            esac

            info_msg "re-packaging ${name}"
            local tmp_dir=/tmp/${name}
            rm -rf ${tmp_dir}
            mkdir -p ${tmp_dir}
            eval tar -x${archive}f ${download_dir}/${name} -C ${tmp_dir} --strip-components 1
            eval tar -czf ${packages_dir}/${name}.tar.gz --exclude-vcs -C /tmp ${name}
        else
            echo "exists"
            continue
        fi
    done
}


help()
{
	echo
	info_msg "Usage:"
	info_msg "	update.sh [target]"
	echo
	info_msg "Example:"
	info_msg "	update.sh sources"
	info_msg "	update.sh archive"
	info_msg "	update.sh all"
	echo
}


######################################################################################
TARGET="$1"
case "$TARGET" in
	sources)
		update_sources
		;;
	archive)
		update_archive
		;;
	all)
		update_sources
		update_archive
		;;
	*)
		error_msg "Unsupported target: $TARGET"
		help
		exit -1
		;;
esac



echo
info_msg "Done."
ls ${packages_dir} -lh
