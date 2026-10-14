#!/usr/bin/env bash
# Prints KERNEL_VERSION and KERNEL_TAG for the prebuilt kernel release.
# The tag includes a hash of the config and build script, so changing either
# one produces a new release instead of reusing a stale build.

set -euo pipefail

cd "$(dirname "$0")"

version=${KERNEL_VERSION:-$(ls -1 *.config | sed 's/\.config$//' | sort -V | tail -n 1)}
hash=$(cat "$version.config" build.sh | sha256sum | cut -c1-8)

echo "KERNEL_VERSION=$version"
echo "KERNEL_TAG=kernel-$version-$hash"
