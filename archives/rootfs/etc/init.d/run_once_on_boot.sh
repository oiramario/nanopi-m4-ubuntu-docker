#!/bin/sh -e
#

# disk space recovery
resize2fs /dev/mmcblk1p7 >/dev/null 2>&1

# update locate database
updatedb >/dev/null 2>&1

# generate the SSH keys if non-existent
ssh-keygen -A >/dev/null 2>&1

# run once
if [ $? -eq 0 ] ; then
    # self destruction
    rm $0
fi

exit 0
