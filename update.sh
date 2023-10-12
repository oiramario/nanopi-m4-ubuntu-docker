#!/bin/bash
#
#set -x

source scripts/functions/common.sh


download_dir=$(pwd)/downloads
[ ! -d ${download_dir} ] && mkdir -p ${download_dir}

packages_dir=$(pwd)/packages
[ ! -d ${packages_dir} ] && mkdir -p ${packages_dir}

packages_3rdparty_dir=${packages_dir}
[ ! -d ${packages_3rdparty_dir} ] && mkdir -p ${packages_3rdparty_dir}

update_sources()
{
    local github_url=(
        "https://github.com"
    )

    #friendlyarm/uboot-rockchip does not support MMC_MODE_HS400(150MHz), only 50MHz.
    local gits=(
        "core,rkbin,FreshLuoBoGan/rkbin.git,stable-4.4-rk3399-linux"
        "core,u-boot,friendlyarm/uboot-rockchip,nanopi4-v2021.07"
        "core,kernel,friendlyarm/kernel-rockchip.git,nanopi4-linux-v4.4.y"
        "core,busybox,mirror/busybox.git,1_36_stable"
        "core,rk-rootfs-build,friendlyarm/rk-rootfs-build.git,master"
        "core,alsa-lib,alsa-project/alsa-lib.git,v1.2.10"
        "core,libdrm,xiaoshzx/libdrm-rockchip-1.git,rockchip-2.4.97"
        "core,libmali,oiramario/libmali.git,rk3399-r14p0"
        "core,librga,airockchip/librga.git,main"
        "core,mpp,oiramario/mpp.git,release"
        "core,zlib,madler/zlib.git,v1.3"
        "core,libjpeg,libjpeg-turbo/libjpeg-turbo.git,3.0.0"
        "core,libpng,glennrp/libpng.git,v1.6.37"
        "core,ffmpeg,oiramario/ffmpeg.git,v4.2.4-ubuntu20.04"
        "core,sdl,spurious/SDL-mirror.git,release-2.0.14"
        "core,mpv,oiramario/mpv.git,0.32.0-ubuntu20.04"
        "3rdparty,librealsense,IntelRealSense/librealsense.git,v2.41.0"
        "3rdparty,gdb,bminor/binutils-gdb.git,gdb-8.3-branch"
        "3rdparty,sdlpal,sdlpal/sdlpal.git,master"
        "3rdparty,glmark2,glmark2/glmark2.git,release-2020.04"
        "3rdparty,realsense_test,oiramario/gbm-drm-gles-cube.git,master"
        "3rdparty,opencl_test,oiramario/hellocl.git,master"
        "3rdparty,gl4es,ptitSeb/gl4es.git,v1.1.4"
        "3rdparty,mame,mamedev/mame.git,mame0227"
    )

    cd ${download_dir}

    for i in ${gits[@]}
    do
        local str=($i)
        local arr=(${str//,/ })

        local type=${arr[0]}
        local name=${arr[1]}
        local link=${arr[2]}
        local branch=${arr[3]}

        local do_pack=1
        local pak_dir=${packages_dir}
        [ ${type} = "3rdparty" ] && pak_dir=${packages_3rdparty_dir}

        echo
        info_msg "checking ${name}"
        # try 3 times
        for n in {0..2}
        do
            # change github mirror
            local url="${github_url[$n]}/${link}"
            if [ ! -d ${name} ]
            then
                git clone --depth 1 --branch ${branch} --single-branch ${url} ${name}
                git submodule update --init --recursive
            else
                local ret=$(git -C ${name} pull)
                if [[ ${ret} =~ "Already up to date." ]]
                then
                    echo "up-to-date sources"
                    if [ -f ${pak_dir}/${name}.tar.gz ]
                    then
                        do_pack=0
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

        if [ $do_pack -eq 1 ] ; then
            echo "packaging"
            # exclude some bigger but useless files
            local exclude="--exclude-vcs"
            if [ $name = "rkbin" ];then
                exclude+=" \
                    --exclude=rkbin/bin/rk1x \
                    --exclude=rkbin/bin/rk30 \
                    --exclude=rkbin/bin/rk31 \
                    --exclude=rkbin/bin/rk32 \
                    --exclude=rkbin/bin/rk35 \
                    --exclude=rkbin/bin/rv11 \
                    --exclude=rkbin/img \
                    --exclude=rkbin/tools/upgrade_tool \
                    "
            elif [ ${name} = "rk-rootfs-build" ];then
                exclude+=" \
                    --exclude=*.md \
                    --exclude=${name}/mk-*.sh \
                    --exclude=overlay \
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
            elif [ $name = "librealsense" ];then
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
            elif [ $name = "gdb" ];then
                exclude+=" \
                    --exclude=gas \
                    --exclude=sim \
                    --exclude=ld \
                    --exclude=binutils \
                    --exclude=gold"
            elif [ $name = "gl4es" ];then
                exclude+=" \
                    --exclude=traces"
            elif [ $name = "sdlpal" ];then
                exclude=""
            fi

            eval tar -czf ${pak_dir}/${name}.tar.gz $exclude -C . ${name} --checkpoint=1000 --checkpoint-action=dot --totals
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
