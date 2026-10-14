#!/usr/bin/env bash
# Builds the Steam Link kernel from kernel/<version>.config, using the kernel.org
# source and the Steam Link SDK toolchain (GCC 9.2, x86-64 only).
#
# Usage: kernel/build.sh <output-dir>
#
# Produces in <output-dir>: zImage, berlin2cd-valve-steamlink.dtb,
# config-<version>-steam and the <version>-steam modules directory.
#
# Needs: bc bison curl flex gcc git kmod libc6-dev libelf-dev libssl-dev make
# perl xz-utils

set -euo pipefail

KERNEL_DIR=$(cd "$(dirname "$0")" && pwd)
KERNEL_VERSION=${KERNEL_VERSION:-$(cd "$KERNEL_DIR" && ls -1 *.config | sed 's/\.config$//' | sort -V | tail -n 1)}
RELEASE="$KERNEL_VERSION-steam"

OUT=$(realpath -m "$1")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$KERNEL_DIR/$KERNEL_VERSION.config" ]; then
    echo "No kernel/$KERNEL_VERSION.config for kernel $KERNEL_VERSION" >&2
    exit 1
fi

# Without depmod, modules_install only warns and ships no module index
if ! PATH="$PATH:/sbin:/usr/sbin" command -v depmod > /dev/null; then
    echo "depmod not found, install kmod" >&2
    exit 1
fi

SRC="$WORK/linux-$KERNEL_VERSION"
SDK="$WORK/steamlink-sdk"

echo "Downloading Linux $KERNEL_VERSION"
curl -fsSL --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz" \
    | tar -xJ -C "$WORK"

echo "Downloading Steam Link SDK toolchain"
git clone -q --depth=1 --filter=blob:none --sparse https://github.com/ValveSoftware/steamlink-sdk.git "$SDK"
git -C "$SDK" sparse-checkout set toolchain

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

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$SRC/arch/arm/boot/zImage" "$OUT/"
cp "$SRC/arch/arm/boot/dts/synaptics/berlin2cd-valve-steamlink.dtb" "$OUT/"
cp "$SRC/.config" "$OUT/config-$RELEASE"

make -C "$SRC" INSTALL_MOD_PATH="$WORK/modules" INSTALL_MOD_STRIP=1 modules_install
mv "$WORK/modules/lib/modules/$RELEASE" "$OUT/"
rm -f "$OUT/$RELEASE/build" "$OUT/$RELEASE/source"

echo "Built kernel $RELEASE in $OUT"
