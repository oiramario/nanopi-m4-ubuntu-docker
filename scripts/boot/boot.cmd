setenv bootargs console=ttyFIQ0 rw root=/dev/mmcblk1p6 rootfstype=ext4 rootwait
setenv fit_addr 0x4000000
ext4load mmc 0:5 $fit_addr /fitImage.itb
bootm $fit_addr
