rk3399-docker
=============
Build own ubuntu 18.04 base minimal image for RK3399 (NanoPi M4 / T4 / NEO4)

OS Image for development with the following tidbits:

* Kernel 4.4.y
* u-boot 2.0
* overlay-firmware 2018.10
* busybox 1.30.1
* libdrm 2.4.91
* mali 14.0
* libusb 1.0.22
* librealsense2 2.18.1
 
# boot

### kernel

    git clone https://github.com/friendlyarm/kernel-rockchip.git --depth 1 -b nanopi4-linux-v4.4.y kernel
    git clone https://github.com/rockchip-linux/kernel.git --depth 1 -b stable-4.4-rk3399-linux kernel

### u-boot

* u-boot

        git clone https://github.com/rockchip-linux/u-boot.git --depth 1 -b stable-4.4-rk3399-linux u-boot

* rkbin

        git clone https://github.com/rockchip-linux/rkbin.git --depth 1 rkbin

### rootfs

* libdrm

        git clone https://github.com/numbqq/libdrm-rockchip.git --depth 1 -b rockchip-2.4.91 libdrm-2.4.91

* mali

        git clone https://github.com/rockchip-linux/libmali.git --depth 1 -b rockchip

* eudev

        wget https://github.com/gentoo/eudev/archive/v3.2.7.tar.gz

* libusb

        wget https://github.com/libusb/libusb/archive/v1.0.22.tar.gz

* librealsense2

        wget https://github.com/IntelRealSense/librealsense/archive/v2.18.1.tar.gz

* busybox

        wget https://github.com/mirror/busybox/archive/1_30_1.tar.gz

* nanopi4-overlay-firmware

        git clone https://github.com/nishantpoorswani/nanopi-m4-bin --depth 1

# howto
    apt-get install docker git-lfs tree
    git lfs clone https://github.com/oiramario/rk3399-docker.git
    cd rk3399-docker
    ./build.sh

# tips
### docker
* remove none images

        docker stop $(docker ps -a | grep "Exited" | awk '{print $1 }')
        docker rm $(docker ps -a | grep "Exited" | awk '{print $1 }')
        docker rmi $(docker images | grep "none" | awk '{print $3}')

* remove all container

        docker container prune -f

* remove all images

        docker rmi $(docker images -q)

* build

        docker build -t rk3399 ./rk3399-docker

* run

        docker container run -it rk3399 /bin/bash

### git
* faster git clone

        echo '151.101.72.249 github.global.ssl.fastly.net' >> /etc/hosts
        echo '192.30.253.112 github.com' >> /etc/hosts
        /etc/init.d/networking restart

* avoid getting asked for credentials every time

        git config --global credential.helper wincred

* git-lfs upload
    * move packages outside

            git init
            git lfs track "*.tar.xz"
            git add .
            git commit -m "first commit"
            git remote add origin git@github.com:oiramario/rk3399-docker.git
            git push -u origin master

    * move packages back

            git add .
            git commit -m "add packages"
            git lfs ls-files
            git push origin master
