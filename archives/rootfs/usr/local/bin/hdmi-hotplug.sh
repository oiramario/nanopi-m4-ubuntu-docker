#!/bin/sh

# card 0: mini jack
# card 1: rockchiphdmi
pcm_card=${1-0}

sed -i "/^defaults.pcm.card/cdefaults.pcm.card ${pcm_card}" /etc/asound.conf
