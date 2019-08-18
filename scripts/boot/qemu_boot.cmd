setenv image_addr 0x80000000
ext4load virtio 0:1 $image_addr /fitImage.itb
bootm $image_addr
