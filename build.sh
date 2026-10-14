#!/usr/bin/env bash
# Builds the Steam Link Debian image from scratch: kernel, root filesystem and
# disk image, all inside Docker. The result is out/steamlink-debian.img.xz.
#
# Usage: ./build.sh [extra docker build options]
#
# The kernel is kept in Docker's build cache and only recompiled when kernel/
# changes. Use ./build.sh --no-cache to rebuild everything.

set -euo pipefail

cd "$(dirname "$0")"

# The root filesystem is built for armhf, which needs QEMU emulation on other hosts
if ! docker run --rm --platform linux/arm/v7 docker.io/arm32v7/debian:trixie true > /dev/null 2>&1; then
    echo "Installing QEMU handlers for ARM emulation"
    docker run --rm --privileged docker.io/tonistiigi/binfmt --install arm
fi

docker build --output out "$@" .

echo "Image: out/steamlink-debian.img.xz"
