setenv bootargs "root=/dev/mmcblk1p9 rootfstype=ext4 rw rootwait fsck.repair=yes"

#               start        size                  offset 
# origin        0x00000000   0x00800000(512K)      0x00000000
# kernel        0x00080000   0x01200000(18M)       0x00200000(2M) = 0x1400000
# initrd        0x01400000   0x00200000(2M)        0x00200000(2M) = 0x1800000

setenv fit_addr 0x1800000
ext4load mmc 0:8 $fit_addr /rk3399.itb
bootm $fit_addr
