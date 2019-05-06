./tools/rkdeveloptool db ./distro/MiniLoaderAll.bin
sleep 1
./tools/rkdeveloptool wl 0x4000 ./distro/uboot.img
sleep 1
./tools/rkdeveloptool wl 0x6000 ./distro/trust.img
sleep 1
./tools/rkdeveloptool wl 0x8000 ./distro/boot.img
sleep 1
./tools/rkdeveloptool rd
