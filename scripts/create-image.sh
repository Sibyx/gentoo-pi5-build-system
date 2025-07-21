#!/bin/bash
set -euo pipefail

echo "=== Creating SD Card Image ==="

OUTPUT_DIR="/build/output"
ROOTFS_DIR="/build/rootfs"
IMAGE_FILE="$OUTPUT_DIR/gentoo-rpi5.img"
IMAGE_SIZE="4G"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create empty image file
echo "Creating $IMAGE_SIZE image file..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=0 seek=4096 status=progress

# Create partition table
echo "Creating partition table..."
parted "$IMAGE_FILE" --script -- mklabel msdos
parted "$IMAGE_FILE" --script -- mkpart primary fat32 1MiB 512MiB
parted "$IMAGE_FILE" --script -- mkpart primary ext4 512MiB 100%
parted "$IMAGE_FILE" --script -- set 1 boot on

# Set up loop device
LOOP_DEVICE=$(losetup --find --show "$IMAGE_FILE")
echo "Using loop device: $LOOP_DEVICE"

# Create partition devices
partprobe "$LOOP_DEVICE"
BOOT_PARTITION="${LOOP_DEVICE}p1"
ROOT_PARTITION="${LOOP_DEVICE}p2"

# Wait for partition devices to be ready
sleep 2

# Format partitions
echo "Formatting boot partition (FAT32)..."
mkfs.vfat -F 32 -n "BOOT" "$BOOT_PARTITION"

echo "Formatting root partition (ext4)..."
mkfs.ext4 -L "rootfs" "$ROOT_PARTITION"

# Mount partitions
MOUNT_POINT="/mnt/rpi-image"
mkdir -p "$MOUNT_POINT"
mount "$ROOT_PARTITION" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/boot"
mount "$BOOT_PARTITION" "$MOUNT_POINT/boot"

# Copy root filesystem
echo "Copying root filesystem..."
rsync -aHAXx --exclude='/boot/*' "$ROOTFS_DIR/" "$MOUNT_POINT/"

# Copy boot files
echo "Copying boot files..."
cp "$OUTPUT_DIR/boot/kernel8.img" "$MOUNT_POINT/boot/"
cp "$OUTPUT_DIR/boot/bcm2712-rpi-5-b.dtb" "$MOUNT_POINT/boot/"
cp -r "$OUTPUT_DIR/boot/overlays" "$MOUNT_POINT/boot/" 2>/dev/null || true

# Download and install Raspberry Pi firmware
echo "Installing Raspberry Pi firmware..."
FIRMWARE_DIR="/tmp/firmware"
if [ ! -d "$FIRMWARE_DIR" ]; then
    git clone --depth=1 https://github.com/raspberrypi/firmware.git "$FIRMWARE_DIR"
fi

# Copy essential firmware files
cp "$FIRMWARE_DIR/boot/start4.elf" "$MOUNT_POINT/boot/"
cp "$FIRMWARE_DIR/boot/fixup4.dat" "$MOUNT_POINT/boot/"
cp "$FIRMWARE_DIR/boot/bootcode.bin" "$MOUNT_POINT/boot/" 2>/dev/null || true

# Copy already prepared config files
cp "$ROOTFS_DIR/boot/config.txt" "$MOUNT_POINT/boot/"
cp "$ROOTFS_DIR/boot/cmdline.txt" "$MOUNT_POINT/boot/"

# Enable SSH by creating ssh file in boot partition
touch "$MOUNT_POINT/boot/ssh"

# Set correct permissions
echo "Setting permissions..."
chown -R 0:0 "$MOUNT_POINT"
chmod 755 "$MOUNT_POINT"

# Create WiFi configuration in boot partition for easy access
if [ -n "${WIFI_SSID:-}" ] && [ -n "${WIFI_PASSWORD:-}" ]; then
    echo "Creating wpa_supplicant.conf in boot partition..."
    cat > "$MOUNT_POINT/boot/wpa_supplicant.conf" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-US}

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
fi

# Sync and unmount
echo "Syncing and unmounting..."
sync
umount "$MOUNT_POINT/boot"
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

# Detach loop device
losetup -d "$LOOP_DEVICE"

# Compress image
echo "Compressing image..."
cd "$OUTPUT_DIR"
xz -z -k "gentoo-rpi5.img"

echo "SD card image created successfully!"
echo "Image location: $OUTPUT_DIR/gentoo-rpi5.img"
echo "Compressed image: $OUTPUT_DIR/gentoo-rpi5.img.xz"
echo ""
echo "To flash to SD card:"
echo "  dd if=gentoo-rpi5.img of=/dev/sdX bs=4M status=progress"
echo "  or use balenaEtcher with the .xz file"
echo ""
echo "Default credentials:"
echo "  User: pi / Password: raspberry"
echo "  Root login enabled via SSH"
echo "  Hostname: rpi5-gentoo.local"