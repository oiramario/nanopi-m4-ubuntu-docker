#!/bin/bash
#
#set -x

if [ "$1" != "all" ]; then
    docker stop $(docker ps -a | grep "Exited" | awk '{print $1 }')
    docker rm $(docker ps -a | grep "Exited" | awk '{print $1 }')
    docker rmi $(docker images | grep "none" | awk '{print $3}')
else
    docker container prune -f
    docker rmi $(docker images -q)
fi

DISTRO=$PWD/distro
rm -rf $DISTRO
