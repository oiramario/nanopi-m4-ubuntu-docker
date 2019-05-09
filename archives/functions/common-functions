# Functions:
# error_msg
# warning_msg
# info_msg
# mount_chroot
# umount_chroot

## Define colors
BLACK="\e[0;30m"
BOLDBLACK="\e[1;30m"
RED="\e[0;31m"
BOLDRED="\e[1;31m"
GREEN="\e[0;32m"
BOLDGREEN="\e[1;32m"
YELLOW="\e[0;33m"
BOLDYELLOW="\e[1;33m"
BLUE="\e[0;34m"
BOLDBLUE="\e[1;34m"
MAGENTA="\e[0;35m"
BOLDMAGENTA="\e[1;35m"
CYAN="\e[0;36m"
BOLDCYAN="\e[1;36m"
WHITE="\e[0;37m"
BOLDWHITE="\e[1;37m"
ENDCOLOR="\e[0m"

##
ERROR="${RED}Error:${ENDCOLOR}"
WARNING="${YELLOW}Warning:${ENDCOLOR}"
INFO="${GREEN}Info:${ENDCOLOR}"


## Print error message
## $1 - message
error_msg() {
	local _FILE=${BASH_SOURCE[1]}
	local _LINE=${BASH_LINENO[0]}

	echo -e "$_FILE:$_LINE" $ERROR "$1"
}

## Print warning message
## $1 - message
warning_msg() {
	local _FILE=${BASH_SOURCE[1]}
	local _LINE=${BASH_LINENO[0]}

    echo -e "$_FILE:$_LINE" $WARNING "$1"
}

## Print information message
## $1 - message
info_msg() {
	echo -e $INFO "$1"
}

## Mount chroot
mount_chroot() {
	local target=$1
	if [ -z "$target" ]; then
		echo "Usage: mount_chroot <target>"
		return -1
	fi
	mount -t proc chproc $target/proc
	mount -t sysfs chsys $target/sys
	mount -t devtmpfs chdev $target/dev || mount --bind /dev $target/dev
	mount -t devpts chpts $target/dev/pts
}

## Umount chroot
umount_chroot() {
	local target=$1
	if [ -z "$target" ]; then
		echo "Usage: umount_chroot <target>"
		return -1
	fi
	umount -l $target/dev/pts
	umount -l $target/dev
	umount -l $target/proc
	if mount | grep "$target/sys/kernel/security" > /dev/null; then
		umount $target/sys/kernel/security
	fi
	umount -l $target/sys
}

## Umount
do_umount() {
	if mount | grep $1 > /dev/null; then
		umount $1
    fi
}
