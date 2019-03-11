rk3399-docker
=============
Build minimal image for RK3399 (NanoPi M4 / T4 / NEO4)

OS Image for development with the following tidbits:

* boot
    * loader1          1.17.115
        * miniloader   1.15
        * usbplug      1.15
        * ddr          1.17
    * u-boot           2017.09
    * trust            1.24
* kernel               4.4.y
* busybox              1.30.1
* overlay-firmware     2018.10
* libdrm               2.4.91
* mali                 14.0
* libusb               1.0.22
* librealsense         2.19.0
 
# boot

### u-boot

* u-boot

        git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/u-boot.git u-boot

* rkbin

        git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/rkbin.git rkbin

### kernel

    git clone --depth 1 -b nanopi4-linux-v4.4.y https://github.com/friendlyarm/kernel-rockchip.git kernel

### rootfs

* busybox

        git clone --depth 1 -b 1_30_stable https://github.com/mirror/busybox.git busybox

* nanopi4-overlay-firmware

        git clone https://github.com/nishantpoorswani/nanopi-m4-bin --depth 1

* libdrm

        git clone https://github.com/numbqq/libdrm-rockchip.git --depth 1 -b rockchip-2.4.91 libdrm-2.4.91

* mali

        git clone https://github.com/rockchip-linux/libmali.git --depth 1 -b rockchip

* eudev

        wget https://github.com/gentoo/eudev/archive/v3.2.7.tar.gz

* libusb

        wget https://github.com/libusb/libusb/archive/v1.0.22.tar.gz

* librealsense

        wget https://github.com/IntelRealSense/librealsense/archive/v2.19.0.tar.gz

# howto
    apt install docker-ce git-lfs
    git lfs install
    git clone https://github.com/oiramario/rk3399-docker.git
    cd rk3399-docker
    ./build.sh

# tips
### docker
* install

        apt install apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install docker-ce

* build

        docker build -t rk3399 .

* run

        docker container run -it rk3399 /bin/bash

* remove none images

        docker stop $(docker ps -a | grep "Exited" | awk '{print $1 }')
        docker rm $(docker ps -a | grep "Exited" | awk '{print $1 }')
        docker rmi $(docker images | grep "none" | awk '{print $3}')

* remove all containers

        docker container prune -f

* remove all images

        docker rmi $(docker images -q)

### git
* speed up git

        echo '192.30.253.118  gist.github.com' >> /etc/hosts
        echo '192.30.255.113  github.com' >> /etc/hosts
        echo '192.30.255.113  www.github.com' >> /etc/hosts
        echo '151.101.185.194 github.global.ssl.fastly.net' >> /etc/hosts
        echo '52.216.236.115  github-cloud.s3.amazonaws.com' >> /etc/hosts
        /etc/init.d/networking restart

* avoid getting asked for credentials every time

        git config --global user.name "alex"
        git config --global user.email alex@example.com
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
