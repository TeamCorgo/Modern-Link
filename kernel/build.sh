#!/usr/bin/env bash

set -e

export ARCH=arm; export LOCALVERSION="-steam"

mkdir boot
cd steamlink-sdk
source setenv.sh
cd ../linux-$KERNEL_VERSION
make oldconfig
make -j$(nproc)
make modules
mkdir /tmp/build-modules
INSTALL_MOD_PATH=/tmp/build-modules make modules_install