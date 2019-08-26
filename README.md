rk3399-docker
=============
Build minimal image for RK3399 (NanoPi M4 / T4 / NEO4)

OS Image for development with the following tidbits:

* boot
    * loader1
        * miniloader
        * usbplug
        * ddr
    * u-boot
    * trust
* kernel
* busybox
* overlay-firmware
* libdrm
* mali
* libusb
* librealsense
 
# boot

### u-boot

* rkbin

        git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/rkbin.git rkbin

* u-boot

        git clone --depth 1 -b stable-4.4-rk3399-linux https://github.com/rockchip-linux/u-boot.git u-boot

### kernel

    git clone --depth 1 -b nanopi4-linux-v4.4.y https://github.com/friendlyarm/kernel-rockchip.git kernel

### rootfs

* busybox

        git clone --depth 1 -b 1_30_stable https://github.com/mirror/busybox.git busybox

* rk-rootfs-build

        git clone --depth 1 -b master https://github.com/friendlyarm/rk-rootfs-build.git rk-rootfs-build

* mali

        git clone --depth 1 -b rockchip https://github.com/rockchip-linux/libmali.git --depth 1 -b libmali

# build

    apt install docker-ce git
    git clone https://github.com/oiramario/rk3399-docker.git
    cd rk3399-docker
    ./update.sh
    ./build.sh
    ./run.sh

# tips
### hosts
* update

        https://github.com/googlehosts/hosts/blob/master/hosts-files/hosts

* restart

        /etc/init.d/networking restart

### qemu
        apt-get install binfmt-support qemu qemu-user-static debootstrap

### vscode
* install

        snap install code --classic

* fix watcher limit

        echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
        echo '
        "files.watcherExclude": {
                "**/.git/objects/**": true,
                "**/.git/subtree-cache/**": true,
                "**/node_modules/*/**": true
        }' >> $HOME/.config/Code/User/settings.json

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

        echo "
        # Github Start
        192.30.255.112	github.com
        192.30.255.112	www.github.com
        151.101.185.194 github.global.ssl.fastly.net
        52.216.176.59   github-cloud.s3.amazonaws.com
        140.82.113.9    codeload.github.com
        # Github End
        " >> /etc/hosts
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

* shadowsocks

        wget https://github.com/shadowsocks/shadowsocks-qt5/releases/download/v3.0.1/Shadowsocks-Qt5-3.0.1-x86_64.AppImage
        
        git config --global http.proxy socks5://127.0.0.1:1080
        git config --global https.proxy socks5://127.0.0.1:1080
