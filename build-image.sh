#!/usr/bin/env bash
# Builds the Steam Link USB disk image: a Debian 13 (trixie) server install for
# armhf, plus the files in debian/ and a kernel built by kernel/build.sh.
#
# Usage: ./build-image.sh <kernel-dir> <output-dir>
#
# Produces <output-dir>/steamlink-debian.img.xz. Run as root on Debian with
# mmdebstrap, arch-test, e2fsprogs, fdisk, xz-utils and QEMU ARM emulation.

set -euo pipefail

cd "$(dirname "$0")"

export KERNEL OVERLAY RELEASE
KERNEL=$(realpath "$1")
OVERLAY="$PWD/debian"
RELEASE=$(basename "$(find "$KERNEL" -mindepth 1 -maxdepth 1 -type d -name '*-steam')")
OUT=$(realpath -m "$2")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/rootfs"

MIRROR_COMPONENTS="main contrib non-free non-free-firmware"

# A Debian server install: the required, important and standard priority
# packages ("standard system utilities") with their recommends, and "SSH server"
mmdebstrap \
    --mode=root \
    --arch=armhf \
    --variant=standard \
    --aptopt='Apt::Install-Recommends "true"' \
    --include=task-ssh-server \
    --include=systemd-timesyncd,dbus,ca-certificates,dhcpcd-base,ifupdown,sudo,locales \
    --include=nftables,iptables,net-tools,wget,unzip,binutils,libatomic1,vim \
    --include=dosfstools,e2fsprogs,parted,initramfs-tools,firmware-libertas,wireless-regdb \
    --include=dialog,tasksel \
    --customize-hook='rm -f "$1/etc/apt/sources.list" "$1/etc/apt/apt.conf.d/99mmdebstrap" "$1/etc/resolv.conf"' \
    --customize-hook='cp -R --preserve=mode,timestamps "$OVERLAY/." "$1/"' \
    --customize-hook='cp "$KERNEL/zImage" "$KERNEL"/*.dtb "$KERNEL/config-$RELEASE" "$1/boot/"' \
    --customize-hook='mkdir -p "$1/usr/lib/modules" && cp -R "$KERNEL/$RELEASE" "$1/usr/lib/modules/"' \
    --customize-hook='chroot "$1" locale-gen' \
    --customize-hook='chroot "$1" useradd -m -s /bin/bash corgo' \
    --customize-hook='echo corgo:steamlink | chroot "$1" chpasswd' \
    --customize-hook='for g in sudo cdrom floppy audio dip video plugdev users netdev; do
        if chroot "$1" getent group "$g" > /dev/null; then chroot "$1" usermod -a -G "$g" corgo; fi
    done' \
    --customize-hook='chroot "$1" systemctl enable ssh networking systemd-timesyncd' \
    --customize-hook='chroot "$1" mkinitramfs -o /boot/initramfs-linux-steam.img "$RELEASE"' \
    trixie "$ROOT" \
    "deb http://deb.debian.org/debian trixie $MIRROR_COMPONENTS" \
    "deb http://deb.debian.org/debian trixie-updates $MIRROR_COMPONENTS" \
    "deb http://security.debian.org/debian-security trixie-security $MIRROR_COMPONENTS"

# Size the filesystem to the root filesystem plus ~30% and 256 MiB of headroom
ROOTFS_MB=$(du -sm "$ROOT" | cut -f1)
FS_MB=$(( ROOTFS_MB * 13 / 10 + 256 ))
echo "Root filesystem is ${ROOTFS_MB} MiB, creating a ${FS_MB} MiB partition"

mkdir -p "$OUT"
IMG="$OUT/steamlink-debian.img"
mkfs.ext3 -F -q -d "$ROOT" "$WORK/rootfs.ext3" "${FS_MB}M"

# One primary Linux partition from 1 MiB to the end, holding that filesystem
rm -f "$IMG" "$IMG.xz"
truncate -s $(( FS_MB + 1 ))M "$IMG"
echo 'start=2048, type=83' | sfdisk --quiet "$IMG"
dd if="$WORK/rootfs.ext3" of="$IMG" bs=1M seek=1 conv=notrunc,sparse status=none

xz -T0 "$IMG"
echo "Created $IMG.xz"
