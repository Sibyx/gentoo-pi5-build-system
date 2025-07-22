#!/bin/bash
set -euo pipefail

echo "=== Creating SD Card Image (Universal Method) ==="

OUTPUT_DIR="/build/output"
ROOTFS_DIR="/build/rootfs"
IMAGE_FILE="$OUTPUT_DIR/gentoo-rpi5.img"
IMAGE_SIZE_MB=4096

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Calculate partition layout (512-byte sectors)
BOOT_START=2048
BOOT_SIZE=1046528  # ~512MB
ROOT_START=1048576
ROOT_SIZE=$(((IMAGE_SIZE_MB * 2048) - ROOT_START))

echo "Creating ${IMAGE_SIZE_MB}MB image file..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count="$IMAGE_SIZE_MB" status=progress

echo "Partition layout:"
echo "  Boot: sectors $BOOT_START-$((BOOT_START + BOOT_SIZE - 1)) ($(($BOOT_SIZE / 2048))MB)"
echo "  Root: sectors $ROOT_START-$((ROOT_START + ROOT_SIZE - 1)) ($(($ROOT_SIZE / 2048))MB)"

# Create partition table using fdisk
echo "Creating partition table..."
fdisk "$IMAGE_FILE" << 'FDISK_EOF'
o
n
p
1
2048
1048575
t
c
a
n
p
2
1048576

w
FDISK_EOF

# Create temporary filesystem images
echo "Creating filesystem images..."
BOOT_IMG="/tmp/boot-fs-$$.img"
ROOT_IMG="/tmp/root-fs-$$.img"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    umount /tmp/boot-mount-$$ 2>/dev/null || true
    umount /tmp/root-mount-$$ 2>/dev/null || true
    rmdir /tmp/boot-mount-$$ /tmp/root-mount-$$ 2>/dev/null || true
    rm -f "$BOOT_IMG" "$ROOT_IMG" 2>/dev/null || true
}
trap cleanup EXIT

# Create boot filesystem (FAT32)
echo "Creating boot filesystem..."
dd if=/dev/zero of="$BOOT_IMG" bs=512 count="$BOOT_SIZE" status=none
mkfs.vfat -F 32 -n "BOOT" "$BOOT_IMG"

# Create root filesystem (ext4)
echo "Creating root filesystem..."
dd if=/dev/zero of="$ROOT_IMG" bs=512 count="$ROOT_SIZE" status=none
mkfs.ext4 -F -L "rootfs" "$ROOT_IMG"

# Create mount points
BOOT_MOUNT="/tmp/boot-mount-$$"
ROOT_MOUNT="/tmp/root-mount-$$"
mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

# Mount filesystems directly (universal method)
echo "Mounting filesystems..."
mount -o loop "$BOOT_IMG" "$BOOT_MOUNT"
mount -o loop "$ROOT_IMG" "$ROOT_MOUNT"

# Copy root filesystem (excluding boot and virtual filesystems)
echo "Copying root filesystem..."
if [ -d "$ROOTFS_DIR" ]; then
    rsync -aHAX --exclude='/boot/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' "$ROOTFS_DIR/" "$ROOT_MOUNT/"
    
    # Recreate essential directories
    mkdir -p "$ROOT_MOUNT"/{proc,sys,dev,tmp}
    chmod 1777 "$ROOT_MOUNT/tmp"
    
    # Create basic device nodes
    mknod "$ROOT_MOUNT/dev/null" c 1 3 2>/dev/null || true
    mknod "$ROOT_MOUNT/dev/zero" c 1 5 2>/dev/null || true
    mknod "$ROOT_MOUNT/dev/random" c 1 8 2>/dev/null || true
    mknod "$ROOT_MOUNT/dev/urandom" c 1 9 2>/dev/null || true
    chmod 666 "$ROOT_MOUNT/dev/null" "$ROOT_MOUNT/dev/zero" "$ROOT_MOUNT/dev/random" "$ROOT_MOUNT/dev/urandom" 2>/dev/null || true
fi

# Copy kernel and device tree to boot partition
echo "Installing kernel and device tree..."
if [ -f "$OUTPUT_DIR/boot/kernel8.img" ]; then
    cp "$OUTPUT_DIR/boot/kernel8.img" "$BOOT_MOUNT/"
else
    echo "Warning: kernel8.img not found in $OUTPUT_DIR/boot/"
fi

if [ -f "$OUTPUT_DIR/boot/bcm2712-rpi-5-b.dtb" ]; then
    cp "$OUTPUT_DIR/boot/bcm2712-rpi-5-b.dtb" "$BOOT_MOUNT/"
else
    echo "Warning: bcm2712-rpi-5-b.dtb not found"
fi

# Copy overlays if they exist
if [ -d "$OUTPUT_DIR/boot/overlays" ]; then
    cp -r "$OUTPUT_DIR/boot/overlays" "$BOOT_MOUNT/"
fi

# Download and install Raspberry Pi firmware
echo "Installing Raspberry Pi firmware..."
FIRMWARE_DIR="/tmp/firmware"
if [ ! -d "$FIRMWARE_DIR" ]; then
    echo "Downloading Raspberry Pi firmware..."
    git clone --depth=1 --single-branch https://github.com/raspberrypi/firmware.git "$FIRMWARE_DIR"
fi

# Copy essential firmware files
echo "Copying firmware files..."
cp "$FIRMWARE_DIR/boot/start4.elf" "$BOOT_MOUNT/"
cp "$FIRMWARE_DIR/boot/fixup4.dat" "$BOOT_MOUNT/"

# For RPi5, also copy RPi5-specific files if they exist
if [ -f "$FIRMWARE_DIR/boot/start_cd.elf" ]; then
    cp "$FIRMWARE_DIR/boot/start_cd.elf" "$BOOT_MOUNT/"
fi
if [ -f "$FIRMWARE_DIR/boot/fixup_cd.dat" ]; then
    cp "$FIRMWARE_DIR/boot/fixup_cd.dat" "$BOOT_MOUNT/"
fi

# Copy boot configuration files
if [ -f "$ROOTFS_DIR/boot/config.txt" ]; then
    cp "$ROOTFS_DIR/boot/config.txt" "$BOOT_MOUNT/"
else
    echo "Warning: config.txt not found in rootfs"
fi

if [ -f "$ROOTFS_DIR/boot/cmdline.txt" ]; then
    cp "$ROOTFS_DIR/boot/cmdline.txt" "$BOOT_MOUNT/"
else
    echo "Warning: cmdline.txt not found in rootfs"
fi

# Enable SSH
touch "$BOOT_MOUNT/ssh"

# Create WiFi configuration in boot partition for Raspberry Pi auto-setup
if [ -n "${WIFI_SSID:-}" ] && [ -n "${WIFI_PASSWORD:-}" ]; then
    echo "Creating WiFi configuration..."
    cat > "$BOOT_MOUNT/wpa_supplicant.conf" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-US}

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
    chmod 600 "$BOOT_MOUNT/wpa_supplicant.conf"
fi

# Set ownership and permissions
echo "Setting permissions..."
chown -R 0:0 "$ROOT_MOUNT" 2>/dev/null || true
chmod 755 "$ROOT_MOUNT"

# Sync and unmount filesystems
echo "Syncing filesystems..."
sync
sleep 2

echo "Unmounting filesystems..."
umount "$BOOT_MOUNT"
umount "$ROOT_MOUNT"

# Filesystems are automatically unmounted by cleanup trap

# Assemble final image using dd with offset
echo "Assembling final image..."
dd if="$BOOT_IMG" of="$IMAGE_FILE" bs=512 seek="$BOOT_START" conv=notrunc status=progress
dd if="$ROOT_IMG" of="$IMAGE_FILE" bs=512 seek="$ROOT_START" conv=notrunc status=progress

# Clean up temporary files (done by trap)
echo "Cleaning up temporary files..."

# Compress image
echo "Compressing image..."
cd "$OUTPUT_DIR"
xz -z -k -T 0 "gentoo-rpi5.img"

# Generate checksum
echo "Generating checksum..."
sha256sum "gentoo-rpi5.img.xz" > "gentoo-rpi5.img.xz.sha256"

echo ""
echo "=== Image Creation Complete! ==="
echo "Image location: $OUTPUT_DIR/gentoo-rpi5.img"
echo "Compressed image: $OUTPUT_DIR/gentoo-rpi5.img.xz"
echo "Checksum: $OUTPUT_DIR/gentoo-rpi5.img.xz.sha256"
echo ""
echo "Image size: $(du -h "$OUTPUT_DIR/gentoo-rpi5.img.xz" | cut -f1)"
echo ""
echo "To flash to SD card:"
echo "  dd if=gentoo-rpi5.img of=/dev/sdX bs=4M status=progress"
echo "  or use balenaEtcher with the .xz file"
echo ""
echo "Default credentials:"
echo "  User: pi / Password: raspberry"
echo "  SSH: ssh pi@rpi5-gentoo.local"
echo ""
echo "WiFi: ${WIFI_SSID:-Not configured}"