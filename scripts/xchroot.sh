source functions/common.sh

rootfs_dir=${BUILD}/rootfs
mount_chroot ${rootfs_dir}
mount binfmt_misc -t binfmt_misc ${rootfs_dir}/proc/sys/fs/binfmt_misc
update-binfmts --enable qemu-aarch64
cp -v /usr/bin/qemu-aarch64-static ${rootfs_dir}/usr/bin/
LC_ALL=C LANG=C chroot ${rootfs_dir}/ /bin/bash
