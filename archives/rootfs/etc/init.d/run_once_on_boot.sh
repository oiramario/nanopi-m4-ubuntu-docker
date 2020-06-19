#!/bin/sh -e
#

# disk space recovery
resize2fs /dev/mmcblk1p6

# update locate database
updatedb

# generate the SSH keys if non-existent
ssh-keygen -A

# run once
if [ $? -eq 0 ] ; then
    # self destruction
    rm $0
fi

exit 0
