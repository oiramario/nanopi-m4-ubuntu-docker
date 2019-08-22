#!/bin/bash
#
#set -x

source scripts/functions/common.sh


download_dir=$(pwd)/downloads
[ ! -d ${download_dir} ] && mkdir -p ${download_dir}

packages_dir=$(pwd)/packages
[ ! -d ${packages_dir} ] && mkdir -p ${packages_dir}

cd ${download_dir}

gits=(
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/rkbin.git,rkbin"
"stable-4.4-rk3399-linux,https://github.com/rockchip-linux/u-boot.git,u-boot"
"nanopi4-linux-v4.4.y,https://github.com/friendlyarm/kernel-rockchip.git,kernel-rockchip"
"master,https://github.com/rockchip-linux/rk-rootfs-build.git,rk-rootfs-build"
)
for i in ${gits[@]}
do
    str=($i)
    arr=(${str//,/ })

    branch=${arr[0]}
    url=${arr[1]}
    dir=${arr[2]}

    echo
    info_msg "checking ${dir}"
    if [ ! -d ${dir} ];then
        git clone --depth 1 --branch ${branch} --single-branch ${url} ${dir}
    else
        ret=$(git -C ${dir} pull)
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
        exclude="--exclude-vcs"
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


cd ..

tars=(
"busybox,https://github.com/mirror/busybox/archive/1_31_0.tar.gz"
"ubuntu-rootfs,http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz"
"qemu,https://download.qemu.org/qemu-4.1.0.tar.xz"
"librealsense,https://github.com/IntelRealSense/librealsense/archive/v2.26.0.tar.gz"
)
for i in ${tars[@]}
do
    str=($i)
    arr=(${str//,/ })

    name=${arr[0]}
    url=${arr[1]}

    echo
    info_msg "checking ${name}"

    if [ ! -f ${download_dir}/${name}.tar ]; then
        wget -O /tmp/${name}.tar ${url}
        if [ $? -eq 0 ] ; then
            cp /tmp/${name}.tar ${download_dir}/
            # re-package
            rm -f ${packages_dir}/${name}.tar.gz
        else
            error_msg "operation failed"
            continue
        fi
    fi

    if [ $? -eq 0 ] && [ ! -f ${packages_dir}/${name}.tar.gz ]; then
        archive="z"
        case "${name}" in
            ubuntu-rootfs)
                cp -v ${download_dir}/${name}.tar ${packages_dir}/${name}.tar.gz
                continue
                ;;
            qemu)
                archive="J"
                ;;
            *)
                ;;
        esac

        info_msg "re-packaging ${name}"
        tmp_dir=/tmp/${name}
        rm -rf ${tmp_dir}
        mkdir -p ${tmp_dir}
        eval tar -x${archive}f ${download_dir}/${name}.tar -C ${tmp_dir} --strip-components 1
        eval tar -czf ${packages_dir}/${name}.tar.gz --exclude-vcs -C /tmp ${name}
    else
        echo "exists"
        continue
    fi
done

echo
info_msg "Done."
ls ${packages_dir} -lh
