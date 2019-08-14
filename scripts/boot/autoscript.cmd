setenv bootargs console=ttyFIQ0 rw root=/dev/mmcblk1p6 rootfstype=ext4 rootwait

#               -start-       -size-               -padding-          -next-
# origin        0x00000000    0x00080000 (512K)    0x00000000         0x00080000
# kernel        0x00080000    0x01200000 (18M)     0x00200000 (2M)    0x01400000
# fdt           0x01400000    0x00200000 (2M)      0x00100000 (1M)    0x01700000
# initrd        0x01700000    0x02000000 (32M)     0x00300000 (3M)    0x04000000

setenv fit_image_addr 0x54000000
ext4load virtio 0:1 $fit_image_addr /fitImage.itb
bootm $fit_image_addr
