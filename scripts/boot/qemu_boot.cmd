setenv bootargs earlyprintk console=ttyAMA0
setenv image_addr 0x50000000
ext4load virtio 0:1 $image_addr /fitImage.itb
bootm $image_addr
