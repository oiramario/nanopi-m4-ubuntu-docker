#!/bin/sh -e
#

if [ $? -eq 0 ] ; then
    # disk space recovery
    resize2fs /dev/mmcblk1p6
fi


if [ $? -eq 0 ] ; then
    # update locate database
    updatedb
fi


if [ $? -eq 0 ] ; then
    # generate the SSH keys if non-existent
    ssh-keygen -A
fi


if [ $? -eq 0 ] ; then
    # alsa mixer configuration(fix no sound issue)
    amixer set 'HPO L' on
    amixer set 'HPO R' on
    amixer set 'HPOVOL L' on
    amixer set 'HPOVOL R' on
    amixer set 'HPO MIX HPVOL' on
    amixer set 'OUT MIXL DAC L1' on
    amixer set 'OUT MIXR DAC R1' on
    amixer set 'Stereo DAC MIXL DAC L1' on
    amixer set 'Stereo DAC MIXR DAC R1' on
    alsactl store
fi


if [ $? -eq 0 ] ; then
    # run once
    rm $0
fi

exit 0
