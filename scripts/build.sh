#!/bin/bash
set -euo pipefail

echo "=== Gentoo Raspberry Pi 5 Image Builder ==="
echo "Build started at: $(date)"

# Validate required environment variables
if [ -z "${WIFI_SSID:-}" ]; then
    echo "Warning: WIFI_SSID not set. WiFi will not be configured automatically."
fi

if [ -z "${WIFI_PASSWORD:-}" ]; then
    echo "Warning: WIFI_PASSWORD not set. WiFi will not be configured automatically."
fi

# Check if we're running in a privileged container
if ! losetup --find >/dev/null 2>&1; then
    echo "Error: This container needs to run with --privileged flag for loop device access"
    exit 1
fi

# Function to handle cleanup on exit
cleanup() {
    echo "Cleaning up..."
    # Unmount any remaining mounts
    umount /mnt/rpi-image/boot 2>/dev/null || true
    umount /mnt/rpi-image 2>/dev/null || true
    # Detach any loop devices
    losetup -D 2>/dev/null || true
}
trap cleanup EXIT

# Build stages
echo ""
echo "Stage 1: Building root filesystem..."
/build/scripts/build-rootfs.sh

echo ""
echo "Stage 2: Building Linux kernel..."
/build/scripts/build-kernel.sh

echo ""
echo "Stage 3: System configuration..."
/build/scripts/configure-system.sh

echo ""
echo "Stage 4: Creating SD card image..."
/build/scripts/create-image.sh

echo ""
echo "=== Build Complete ==="
echo "Build finished at: $(date)"
echo ""
echo "Output files:"
ls -lh /build/output/gentoo-rpi5.img*

echo ""
echo "Build summary:"
echo "- Kernel: Linux ${KERNEL_VERSION:-6.15.7} with WiFi drivers"
echo "- Root filesystem: Gentoo ARM64"
echo "- WiFi SSID: ${WIFI_SSID:-Not configured}"
echo "- SSH: Enabled (pi/raspberry)"
echo "- Hostname: rpi5-gentoo.local"
echo ""
echo "Flash the image to an SD card and boot your Raspberry Pi 5!"