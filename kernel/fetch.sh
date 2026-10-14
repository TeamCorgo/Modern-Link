#!/usr/bin/env bash
# Downloads the prebuilt kernel from GitHub Releases into ./kernel-<version>/
# so rootfs/Dockerfile can use it. Run from the repository root.

set -euo pipefail

REPO=${GITHUB_REPOSITORY:-TeamCorgo/Modern-Link}
eval "$("$(dirname "$0")/release-info.sh")"

asset="kernel-$KERNEL_VERSION.tar.gz"
url="https://github.com/$REPO/releases/download/$KERNEL_TAG/$asset"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "Fetching $KERNEL_TAG"
if ! curl -fsSL --retry 3 -o "$tmp" "$url"; then
    echo "No prebuilt kernel at $url" >&2
    echo "Run the 'Build kernel' workflow for this commit first." >&2
    exit 1
fi

rm -rf "kernel-$KERNEL_VERSION"
tar -xzf "$tmp"
echo "Extracted kernel-$KERNEL_VERSION/"
