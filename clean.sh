#!/bin/bash
#
#set -x

DISTRO=$(pwd)/distro
[ -d $DISTRO ] && rm -rf $DISTRO

docker stop $(docker ps -a | grep "Exited" | awk '{print $1 }')
docker rm $(docker ps -a | grep "Exited" | awk '{print $1 }')
docker rmi $(docker images | grep "none" | awk '{print $3}')
