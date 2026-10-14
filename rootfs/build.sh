#!/usr/bin/env bash

set -e

# Size the image to the root filesystem plus ~30% and 256 MiB of headroom
ROOTFS_MB=$(( $(stat -c %s rootfs.tar) / 1024 / 1024 ))
IMAGE_MB=$(( ROOTFS_MB * 13 / 10 + 256 ))
echo "Root filesystem is ${ROOTFS_MB} MiB, creating a ${IMAGE_MB} MiB image"

dd if=/dev/zero of=steamlink-debian.img bs=1M count=$IMAGE_MB

# Use parted to create a partition table and a single primary partition
parted --script steamlink-debian.img mklabel msdos        # Create an msdos partition table
parted --script steamlink-debian.img mkpart primary ext3 1MiB 100%  # Create a primary partition

sync

# Set up a loop device with partition mapping
LOOP_DEV=$(losetup --show -P -f steamlink-debian.img)

sync

# Format the first partition with ext3
mkfs.ext3 "${LOOP_DEV}p1"

sync

# Mount the partition
mkdir /mnt/disk
mount "${LOOP_DEV}p1" /mnt/disk
tar -xpf rootfs.tar -C /mnt/disk/
rm -rf /mnt/disk/.dockerenv

# Docker leaves these empty; set them up like the Debian installer does
echo steamlink > /mnt/disk/etc/hostname
printf '%s\n' \
    '127.0.0.1	localhost' \
    '127.0.1.1	steamlink' \
    '' \
    '::1	localhost ip6-localhost ip6-loopback' \
    'ff02::1	ip6-allnodes' \
    'ff02::2	ip6-allrouters' > /mnt/disk/etc/hosts
umount -l /mnt/disk

# Detach the loop device
losetup -d $LOOP_DEV

# Compress the image file
xz -z steamlink-debian.img

# Make the image file readable for non-root users
chmod 777 steamlink-debian.img.xz