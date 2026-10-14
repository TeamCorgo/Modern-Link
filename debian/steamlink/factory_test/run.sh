#!/bin/sh

# Keep a log on the USB stick so a failed boot can be inspected from a computer
exec > /mnt/disk/steamlink/factory_test/run.log 2>&1
set -x
date

echo "Resetting crashcounter"
fts-set steamlink.crashcounter 0

echo "Mounting devices"
mount -t proc proc /mnt/disk/proc
mount -o rbind /sys /mnt/disk/sys
mount -o rbind /dev /mnt/disk/dev

sync

echo "Booting into new kernel"
insmod /mnt/disk/boot/kexec_load.ko
chroot /mnt/disk/ /usr/bin/kexec -l /boot/zImage --initrd /boot/initramfs-linux-steam.img --dtb /boot/berlin2cd-valve-steamlink.dtb --command-line "root=/dev/sda1 rootwait rw init=/lib/systemd/systemd console=ttyS0,115200n8 usbcore.autosuspend=-1"
sync
chroot /mnt/disk/ /usr/bin/kexec -e
echo "kexec -e returned $?"
sync
