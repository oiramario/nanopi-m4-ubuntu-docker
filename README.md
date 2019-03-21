rk3399-docker
=============
Build minimal image for RK3399 (NanoPi M4 / T4 / NEO4)

OS Image for development with the following tidbits:

* boot
    * loader1          1.17.115
        * miniloader   1.15
        * usbplug      1.15
        * ddr          1.17
    * u-boot           2019.04-rc3
    * trust            1.24
* kernel               4.4.154
* busybox              1.30.1
* overlay-firmware     2018.10
* libdrm               2.4.91
* mali                 14.0
* libusb               1.0.22
* librealsense         2.19.0
 
# boot

### u-boot

* u-boot

        git clone --depth 1 https://github.com/u-boot/u-boot.git u-boot

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

### parameter
        +----------------------------+---------------------+-------------------+--------------------+----------------+--------------------------------------+
        | Partition                  |     Start Sector    | Number of Sectors |   Partition Size   | PartNum in GPT | Requirements                         |
        +----------------------------+----------+----------+--------+----------+--------------------+----------------+--------------------------------------+
        | MBR                        |        0 | 00000000 |      1 | 00000001 |       512 |  0.5KB |                |                                      |
        | Primary GPT                |        1 | 00000001 |     63 | 0000003F |     32256 | 31.5KB |                |                                      |
        | loader1                    |       64 | 00000040 |   7104 | 00001BC0 |   4096000 |  2.5MB |        1       | preloader (miniloader or U-Boot SPL) |
        | Vendor Storage             |     7168 | 00001C00 |    512 | 00000200 |    262144 |  256KB |                | SN, MAC and etc.                     |
        | Reserved Space             |     7680 | 00001E00 |    384 | 00000180 |    196608 |  192KB |                | Not used                             |
        | reserved1                  |     8064 | 00001F80 |    128 | 00000080 |     65536 |   64KB |                | legacy DRM key                       |
        | U-Boot ENV                 |     8128 | 00001FC0 |     64 | 00000040 |     32768 |   32KB |                |                                      |
        | reserved2                  |     8192 | 00002000 |   8192 | 00002000 |   4194304 |    4MB |                | legacy parameter                     |
        | loader2                    |    16384 | 00004000 |   8192 | 00002000 |   4194304 |    4MB |        2       | U-Boot or UEFI                       |
        | trust                      |    24576 | 00006000 |   8192 | 00002000 |   4194304 |    4MB |        3       | trusted-os like ATF, OP-TEE          |
        | boot(bootable must be set) |    32768 | 00008000 | 229376 | 00038000 | 117440512 |  112MB |        4       | kernel, dtb, extlinux.conf, ramdisk  |
        | rootfs                     |   262144 | 00040000 |    -   |     -    |     -     |    -MB |        5       | Linux system                         |
        | Secondary GPT              | 16777183 | 00FFFFDF |     33 | 00000021 |     16896 | 16.5KB |                |                                      |
        +----------------------------+----------+----------+--------+----------+-----------+--------+----------------+--------------------------------------+



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
        sudo groupadd docker
        sudo gpasswd -a ${USER} docker
        sudo service docker restart
        newgrp - docker

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
