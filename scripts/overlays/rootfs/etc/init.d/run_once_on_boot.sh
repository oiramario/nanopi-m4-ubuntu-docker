#!/bin/sh -e
#

# run once
rm $0

# disk space recovery
resize2fs /dev/mmcblk1p6

# Generate the SSH keys if non-existent
ssh-keygen -A
