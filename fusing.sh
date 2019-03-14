cd build

./rkdeveloptool db MiniLoaderAll.bin
sleep 1

./rkdeveloptool ul MiniLoaderAll.bin
sleep 1

./rkdeveloptool gpt parameter
sleep 1

echo -e "\e[36m 0x40 idbloader.img \e[0m"
./rkdeveloptool wl 0x40    idbloader.img
sleep 1

echo -e "\e[36m 0x4000 uboot.img \e[0m"
./rkdeveloptool wl 0x4000  uboot.img
sleep 1

echo -e "\e[36m 0x6000 trust.img \e[0m"
./rkdeveloptool wl 0x6000  trust.img
sleep 1

echo -e "\e[36m 0x8000 boot.img \e[0m"
./rkdeveloptool wl 0x8000  boot.img
sleep 1

echo -e "\e[36m 0x40000 rootfs.img \e[0m"
./rkdeveloptool wl 0x40000 ubuntu-rootfs.img
sleep 1

echo -e "\e[36m ResetDevice \e[0m"
./rkdeveloptool rd
