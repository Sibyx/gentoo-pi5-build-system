#!/bin/bash
set -euo pipefail

echo "=== Building Root Filesystem ==="

ROOTFS_DIR="/build/rootfs"
STAGE3_URL="${STAGE3_URL:-https://distfiles.gentoo.org/releases/arm64/autobuilds/20250713T232224Z/stage3-arm64-musl-20250713T232224Z.tar.xz}"

# Create rootfs directory
mkdir -p "$ROOTFS_DIR"
cd "$ROOTFS_DIR"

# Download and extract stage3
if [ ! -f ".stage3_extracted" ]; then
    echo "Downloading Gentoo ARM64 stage3..."
    wget -q "$STAGE3_URL" -O stage3.tar.xz
    echo "Extracting stage3..."
    # Use more forgiving extraction options
    tar -xf stage3.tar.xz --numeric-owner --no-same-owner
    rm stage3.tar.xz
    touch .stage3_extracted
fi

echo "Root filesystem build completed!"