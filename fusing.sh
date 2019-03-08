cd rk3399

./rkdeveloptool db rk3399_loader_v1.18.118.bin
sleep 1
#./rkdeveloptool ul MiniLoaderAll.bin

./rkdeveloptool gpt parameter
sleep 1

./rkdeveloptool wl 0x40    idbloader.img
sleep 1

./rkdeveloptool wl 0x4000  uboot.img
sleep 1

./rkdeveloptool wl 0x6000  trust.img
sleep 1

./rkdeveloptool wl 0x8000  boot.img
sleep 1

./rkdeveloptool wl 0x40000 rootfs.img
sleep 1

./rkdeveloptool rd

