# Functions:
# pack_dev_kit

source functions/common.sh


pack_dev_kit()
{
    cp -vrfp ${PREFIX}/* ${NANOPI4_DEVKIT}/
}
