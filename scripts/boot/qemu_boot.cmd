setenv image_addr 0x50000000
ext4load virtio 0:1 $image_addr /uImage
bootm $image_addr
