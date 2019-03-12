# Recompile with:
# mkimage -C none -A arm -T script -d boot.cmd boot.scr

setenv fsck.repair yes
setenv ramdisk initrd.img
setenv kernel Image

setenv env_addr 0x45000000
setenv kernel_addr 0x46000000
setenv ramdisk_addr 0x47000000
setenv dtb_addr 0x48000000
setenv initrd_high 0xffffffff

# 0 = eMMC
# 1 = SD card
setenv boot_from_device 0

ext4load mmc ${boot_from_device} ${kernel_addr_r} ${kernel}
ext4load mmc ${boot_from_device} ${ramdisk_addr_r} ${ramdisk}
setenv ramdisk_size ${filesize}
ext4load mmc ${boot_from_device} ${fdt_addr_r} dtb
#fdt addr ${fdt_addr_r}

# setup MAC address 
#fdt set ethernet0 local-mac-address ${mac_node}

# setup boot_device
#fdt set mmc${boot_mmc} boot_device <1>
setenv extra "no_console_suspend consoleblank=0"
#setenv bootargs "console=ttyS0,115200 earlyprintk root=/dev/mmcblk1p2 rw rootfstype=ext4 rootwait fsck.repair=${fsck.repair} panic=10 ${extra}"
setenv bootargs "earlyprintk root=/dev/mmcblk1p7 rw rootfstype=ext4 rootwait fsck.repair=${fsck.repair} panic=10 ${extra}"
booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr_r}

