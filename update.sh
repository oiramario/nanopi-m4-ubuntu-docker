#!/bin/bash
#
#set -x

source scripts/functions/common.sh


download_dir=$(pwd)/downloads
[ ! -d ${download_dir} ] && mkdir -p ${download_dir}

packages_dir=$(pwd)/packages
[ ! -d ${packages_dir} ] && mkdir -p ${packages_dir}

github_url="github.com.cnpmjs.org"

update_sources()
{
    cd ${download_dir}

    local gits=(
    "rkbin,rockchip-linux/rkbin.git,stable-4.4-rk3399-linux"
    "u-boot,rockchip-linux/u-boot.git,stable-4.4-rk3399-linux"
    "kernel,friendlyarm/kernel-rockchip.git,nanopi4-linux-v4.4.y"
    "rk-rootfs-build,rockchip-linux/rk-rootfs-build.git,master"
    "busybox,mirror/busybox.git,1_31_stable"
#    "librealsense,IntelRealSense/librealsense.git,master"
    )
    for i in ${gits[@]}
    do
        local str=($i)
        local arr=(${str//,/ })

        local dir=${arr[0]}
        local url="https://${github_url}/${arr[1]}"
        local branch=${arr[2]}

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


update_packages()
{
    local tars=(
    "ubuntu-rootfs.tar.gz,http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz"
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
                cp /tmp/${name} ${download_dir}/${name}
            else
                error_msg "operation failed"
                continue
            fi
        else
            echo "exits"
        fi
        cp -f ${download_dir}/${name} ${packages_dir}/${name}
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
	info_msg "	update.sh packages"
	info_msg "	update.sh all"
	echo
}


######################################################################################
TARGET="$1"
case "$TARGET" in
	sources)
		update_sources
		;;
	packages)
		update_packages
		;;
	all)
		update_sources
		update_packages
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
