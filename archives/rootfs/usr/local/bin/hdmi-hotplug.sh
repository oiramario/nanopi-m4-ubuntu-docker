#!/bin/sh

# Get out of town if something errors
set -e

HDMI_STATUS=$(</sys/class/drm/card0/card0-HDMI-A-1/status)

if [ "connected" == "$HDMI_STATUS" ]; then
	export ALSA_PCM_CARD=1
else 
	export ALSA_PCM_CARD=0
fi

exit 0
