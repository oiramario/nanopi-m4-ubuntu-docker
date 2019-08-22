qemu-system-aarch64 \
    -monitor none -serial stdio -no-reboot -nographic \
    -machine virt \
    -cpu cortex-a57 -smp 4 \
    -m 2G,slots=2,maxmem=4G \
    -kernel ./distro/Image \
    -dtb ./distro/rk3399-nanopi4-rev01.dtb \
    -append "console=ttyAMA0"