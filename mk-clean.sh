#!/bin/bash
#
#set -x

echo -e "\e[34m remove docker images ... \e[0m"
if [ "$1" != "all" ]; then
    docker stop $(docker ps -a | grep "Exited" | awk '{print $1 }')
    docker rm $(docker ps -a | grep "Exited" | awk '{print $1 }')
    docker rmi $(docker images | grep "none" | awk '{print $3}')
else
    docker container prune -f
    docker rmi $(docker images -q)
fi


echo -e "\e[34m remove distro ... \e[0m"
DISTRO=$PWD/distro
rm -rf $DISTRO
mkdir -p $DISTRO


echo -e "\e[32m done.\n \e[0m"
