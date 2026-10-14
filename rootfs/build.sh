#!/usr/bin/env bash
# Creates the bootable USB disk image from a root filesystem directory. Run by
# the image stage of the Dockerfile; needs no loop devices or mounting.
#
# Usage: rootfs/build.sh <rootfs-dir> <output-dir>
#
# Produces <output-dir>/steamlink-debian.img.xz.

set -euo pipefail

ROOT=$1
OUT=$2

rm -f "$ROOT/.dockerenv"

# Docker leaves these empty; set them up like the Debian installer does
echo steamlink > "$ROOT/etc/hostname"
printf '%s\n' \
    '127.0.0.1	localhost' \
    '127.0.1.1	steamlink' \
    '' \
    '::1	localhost ip6-localhost ip6-loopback' \
    'ff02::1	ip6-allnodes' \
    'ff02::2	ip6-allrouters' > "$ROOT/etc/hosts"

# Size the filesystem to the root filesystem plus ~30% and 256 MiB of headroom
ROOTFS_MB=$(du -sm "$ROOT" | cut -f1)
FS_MB=$(( ROOTFS_MB * 13 / 10 + 256 ))
echo "Root filesystem is ${ROOTFS_MB} MiB, creating a ${FS_MB} MiB partition"

mkdir -p "$OUT"
FS="$OUT/rootfs.ext3"
IMG="$OUT/steamlink-debian.img"

mkfs.ext3 -F -q -d "$ROOT" "$FS" "${FS_MB}M"

# One primary Linux partition from 1 MiB to the end, holding that filesystem
truncate -s $(( FS_MB + 1 ))M "$IMG"
echo 'start=2048, type=83' | sfdisk --quiet "$IMG"
dd if="$FS" of="$IMG" bs=1M seek=1 conv=notrunc,sparse status=none
rm "$FS"

xz -T0 -f "$IMG"
echo "Created $IMG.xz"
