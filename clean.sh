#!/bin/bash
#
#set -x

source scripts/functions/common.sh

DISTRO=$(pwd)/distro
[ -d $DISTRO ] && rm -rf $DISTRO

info_msg "stop rk3399 containers"
var=$(docker ps -a | grep "rk3399" | awk '{print $1 }')
[ -n "$var" ] && docker stop $var

info_msg "remove rk3399 containers"
var=$(docker ps -a | grep "rk3399" | awk '{print $1 }')
[ -n "$var" ] && docker rm $var

info_msg "remove none images"
var=$(docker images | grep "none" | awk '{print $3}')
[ -n "$var" ] && docker rmi $var
