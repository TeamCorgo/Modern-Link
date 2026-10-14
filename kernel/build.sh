#!/usr/bin/env bash
# Builds the Steam Link kernel and packages it for the rootfs image.
#
# Usage: kernel/build.sh <linux-source-dir> <steamlink-sdk-dir> [output-dir]
#
# Produces <output-dir>/kernel-<version>/ (zImage, dtb, config and the
# <version>-steam modules directory) and a matching .tar.gz.

set -euo pipefail

KERNEL_DIR=$(cd "$(dirname "$0")" && pwd)
eval "$("$KERNEL_DIR/release-info.sh")"

SRC=$(realpath "$1")
SDK=$(realpath "$2")
OUT=$(realpath -m "${3:-.}")
RELEASE="$KERNEL_VERSION-steam"

# Without depmod, modules_install only warns and ships no module index
if ! PATH="$PATH:/sbin:/usr/sbin" command -v depmod > /dev/null; then
    echo "depmod not found, install kmod" >&2
    exit 1
fi

export ARCH=arm LOCALVERSION=-steam CROSS_COMPILE=armv7a-cros-linux-gnueabi-
# The SDK's GCC 9.2 needs the old libgmp/libmpfr bundled alongside it
export PATH="$SDK/toolchain/bin:$PATH" LD_LIBRARY_PATH="$SDK/toolchain/lib" LC_ALL=C

cp "$KERNEL_DIR/$KERNEL_VERSION.config" "$SRC/.config"
make -C "$SRC" olddefconfig

actual=$(make -s -C "$SRC" kernelrelease)
if [ "$actual" != "$RELEASE" ]; then
    echo "Expected kernel release $RELEASE but source reports $actual" >&2
    exit 1
fi

make -C "$SRC" -j"$(nproc)" zImage dtbs modules

PKG="$OUT/kernel-$KERNEL_VERSION"
rm -rf "$PKG"
mkdir -p "$PKG"
cp "$SRC/arch/arm/boot/zImage" "$PKG/"
cp "$SRC/arch/arm/boot/dts/synaptics/berlin2cd-valve-steamlink.dtb" "$PKG/"
cp "$SRC/.config" "$PKG/config-$RELEASE"

MODS=$(mktemp -d)
make -C "$SRC" INSTALL_MOD_PATH="$MODS" INSTALL_MOD_STRIP=1 modules_install
mv "$MODS/lib/modules/$RELEASE" "$PKG/"
rm -rf "$MODS" "$PKG/$RELEASE/build" "$PKG/$RELEASE/source"

tar -C "$OUT" -czf "$OUT/kernel-$KERNEL_VERSION.tar.gz" "kernel-$KERNEL_VERSION"
echo "Packaged $OUT/kernel-$KERNEL_VERSION.tar.gz"
