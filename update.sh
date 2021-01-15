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
    local github_url=(
        "https://github.com.cnpmjs.org"
        "https://github.com"
    )

    local gits=(
        "u-boot,friendlyarm/uboot-rockchip,nanopi4-v2020.10"
        "kernel,friendlyarm/kernel-rockchip.git,nanopi4-linux-v4.4.y"
        "busybox,mirror/busybox.git,1_33_stable"
        "rkbin,oiramario/rkbin.git,stable-4.4-rk3399-linux"
        "rk-rootfs-build,rockchip-linux/rk-rootfs-build.git,master"
        "eudev,gentoo/eudev.git,v3.2.9"
        "libdrm,oiramario/libdrm-rockchip.git,rockchip-2.4.97"
        "libmali,oiramario/libmali.git,rk3399-r14p0"
        "librga,oiramario/linux-rga.git,master"
        "alsa-lib,alsa-project/alsa-lib.git,v1.2.4"
        "mpp,rockchip-linux/mpp.git,release"
        "libusb,libusb/libusb.git,v1.0.24"
        "zlib,madler/zlib.git,v1.2.11"
        "libjpeg,libjpeg-turbo/libjpeg-turbo.git,2.0.90"
        "libpng,glennrp/libpng.git,v1.6.37"
        "ffmpeg,oiramario/ffmpeg.git,v4.2.4-ubuntu20.04"
        "librealsense,IntelRealSense/librealsense.git,v2.41.0"
        "sdl,spurious/SDL-mirror.git,release-2.0.14"
        "gdb,bminor/binutils-gdb.git,gdb-8.3-branch"
        "mpv,oiramario/mpv.git,0.32.0-ubuntu20.04"
        "sdlpal,sdlpal/sdlpal.git,master"
        "realsense_test,oiramario/gbm-drm-gles-cube.git,master"
        "gl4es,ptitSeb/gl4es.git,v1.1.4"
        "glmark2,glmark2/glmark2.git,release-2020.04"
        "opencl_test,oiramario/hellocl.git,master"
    )

    cd ${download_dir}

    for i in ${gits[@]}
    do
        local str=($i)
        local arr=(${str//,/ })

        local dir=${arr[0]}
        local branch=${arr[2]}

        local pack=1
        echo
        info_msg "checking ${dir}"
        # try 3 times
        for n in {0..2}
        do
            # change github mirror
            local url="${github_url[$n]}/${arr[1]}"
            if [ ! -d ${dir} ]
            then
                git clone --depth 1 --branch ${branch} --single-branch ${url} ${dir}
                git submodule update --init --recursive
            else
                local ret=$(git -C ${dir} pull)
                if [[ ${ret} =~ "Already up to date." ]]
                then
                    echo "up-to-date sources"
                    if [ -f ${packages_dir}/${dir}.tar.gz ]
                    then
                        pack=0
                        break
                    fi
                fi
            fi

            if [ $? -eq 0 ]
            then
                break
            else
                error_msg "operation failed, try again(${n})..."
                sleep 1
                echo
            fi
        done

        if [ $pack -eq 1 ] ; then
            echo "packaging"
            # exclude some bigger but useless files
            local exclude="--exclude-vcs"
            if [ ${dir} = "rk-rootfs-build" ];then
                exclude+=" \
                    --exclude=*.md \
                    --exclude=${dir}/mk-*.sh \
                    --exclude=overlay-firmware/usr/share/npu_fw \
                    --exclude=overlay-firmware/usr/share/npu_fw_pcie \
                    --exclude=overlay-firmware/usr/bin/npu* \
                    --exclude=overlay-firmware/usr/bin/upgrade_tool \
                    --exclude=overlay-firmware/usr/bin/brcm_patchram_plus1_32 \
                    --exclude=overlay-firmware/usr/bin/rk_wifi_init_32 \
                    --exclude=packages \
                    --exclude=overlay-debug \
                    --exclude=packages-patches \
                    --exclude=ubuntu-build-service \
                    "
            elif [ $dir = "librealsense" ];then
                exclude+=" \
                    --exclude=wrappers/android \
                    --exclude=wrappers/csharp \
                    --exclude=wrappers/dlib \
                    --exclude=wrappers/matlab \
                    --exclude=wrappers/nodejs \
                    --exclude=wrappers/opencv \
                    --exclude=wrappers/openni2 \
                    --exclude=wrappers/openvino \
                    --exclude=wrappers/pcl \
                    --exclude=wrappers/python \
                    --exclude=wrappers/unity \
                    --exclude=wrappers/unrealengine4 \
                    "
            elif [ $dir = "gdb" ];then
                exclude+=" \
                    --exclude=gas \
                    --exclude=sim \
                    --exclude=ld \
                    --exclude=binutils \
                    --exclude=gold"
            elif [ $dir = "gl4es" ];then
                exclude+=" \
                    --exclude=traces"
            elif [ $dir = "sdlpal" ];then
                exclude=""
            fi

            eval tar -czf ${packages_dir}/${dir}.tar.gz $exclude -C . ${dir} --checkpoint=1000 --checkpoint-action=dot --totals
        fi
    done
}


update_packages()
{
    local tars=(
    "ubuntu-rootfs.tar.gz,http://cdimage.ubuntu.com/ubuntu-base/releases/focal/release/ubuntu-base-20.04-base-arm64.tar.gz"
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
                rm -f ${packages_dir}/${name}
            else
                error_msg "operation failed"
                continue
            fi
        else
            echo "exits"
        fi

        if [ ! -f ${packages_dir}/${name} ]; then
            cp -f ${download_dir}/${name} ${packages_dir}/${name}
        fi
    done
}


######################################################################################
update_sources
update_packages


echo
info_msg "Done."
ls ${packages_dir} -lh
