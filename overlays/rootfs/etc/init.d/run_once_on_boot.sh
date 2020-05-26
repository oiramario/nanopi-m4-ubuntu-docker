#!/bin/sh -e
#

# run once
rm $0

# disk space recovery
resize2fs /dev/mmcblk1p6

# update locate database
updatedb

# generate the SSH keys if non-existent
ssh-keygen -A

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
