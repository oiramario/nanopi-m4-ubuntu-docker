#!/bin/bash
#
#set -x

DISTRO_DIR=$PWD/distro
TOOLS_DIR=$PWD/tools

if [ ! -f "/etc/udev/rules.d/99-rk-rockusb.rules" ]; then
    echo -e "\e[36m add rockusb rules to udev \e[0m"
    sudo cp -f $TOOLS_DIR/99-rk-rockusb.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi


echo -e "\e[36m MiniLoaderAll.bin \e[0m"
$TOOLS_DIR/rkdeveloptool  db  $DISTRO_DIR/MiniLoaderAll.bin
sleep 2

echo -e "\e[36m MiniLoaderAll.bin \e[0m"
$TOOLS_DIR/rkdeveloptool  ul  $DISTRO_DIR/MiniLoaderAll.bin
sleep 1

echo -e "\e[36m parameter.gpt \e[0m"
$TOOLS_DIR/rkdeveloptool  gpt  $TOOLS_DIR/parameter.gpt
sleep 1


parts=`grep 'CMDLINE: mtdparts=rk29xxnand:' tools/parameter.gpt`
parts=${parts#*rk29xxnand:}

OLD_IFS="$IFS" 
IFS="," 
arr=($parts) 
IFS="$OLD_IFS" 
for par in ${arr[@]} 
do 
    size=${par%%@*}
    
    tmp=${par##*@}
    addr=${tmp%%(*}

    name=${tmp##*(}
    name=${name%%)*}
    name=${name%%:*}

    if [ $name != "reserved" ];then
        echo -e "\e[36m $name: addr=$addr size=$size \e[0m"
        $TOOLS_DIR/rkdeveloptool wl $addr $DISTRO_DIR/$name.img
        sleep 1
    fi
done


$TOOLS_DIR/rkdeveloptool rd
