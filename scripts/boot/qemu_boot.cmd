setenv bootargs console=ttyFIQ0 rw root=/dev/mmcblk1p6 rootfstype=ext4 rootwait
setenv kernel_addr_r 0x80080000
setenv fdt_addr 0x40400000
setenv image_addr 0x50000000
ext4load virtio 0:1 $image_addr /fitImage.itb
bootm $image_addr
