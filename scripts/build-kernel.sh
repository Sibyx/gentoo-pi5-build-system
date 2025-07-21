#!/bin/bash
set -euo pipefail

echo "=== Building Linux Kernel for Raspberry Pi 5 ==="

KERNEL_DIR="/build/kernel"
KERNEL_URL="${KERNEL_URL:-https://github.com/raspberrypi/linux/archive/rpi-6.15.y.tar.gz}"
JOBS="$(nproc)"

echo "Using kernel URL: $KERNEL_URL"

# Download and extract kernel source
cd /build
mkdir -p "$KERNEL_DIR"

if [ ! -d "$KERNEL_DIR/linux" ]; then
    echo "Downloading kernel from: $KERNEL_URL"
    KERNEL_ARCHIVE=$(basename "$KERNEL_URL")
    wget -q "$KERNEL_URL" -O "$KERNEL_ARCHIVE"
    
    echo "Extracting kernel source..."
    tar -xf "$KERNEL_ARCHIVE" -C "$KERNEL_DIR"
    
    # Find the extracted directory and rename to 'linux'
    EXTRACTED_DIR=$(find "$KERNEL_DIR" -maxdepth 1 -type d -name "*linux*" | head -1)
    if [ -n "$EXTRACTED_DIR" ]; then
        mv "$EXTRACTED_DIR" "$KERNEL_DIR/linux"
    else
        echo "Error: Could not find extracted kernel directory"
        exit 1
    fi
    
    rm "$KERNEL_ARCHIVE"
fi

cd "$KERNEL_DIR/linux"

# Start with defconfig
echo "Configuring kernel for Raspberry Pi 5..."
if [[ "$KERNEL_URL" == *raspberrypi* ]] || [[ "$KERNEL_URL" == *rpi* ]]; then
    # Raspberry Pi kernel
    make ARCH=arm64 bcm2712_defconfig
else
    # Upstream kernel - use defconfig and enable RPi5 support
    make ARCH=arm64 defconfig
    scripts/config --enable CONFIG_ARCH_BCM2835
    scripts/config --enable CONFIG_ARCH_BCM
fi

# Enable required WiFi and system configurations
echo "Enabling required kernel features..."
scripts/config --enable CONFIG_ARM64
scripts/config --enable CONFIG_BRCMFMAC
scripts/config --enable CONFIG_BRCMFMAC_SDIO
scripts/config --enable CONFIG_BRCMFMAC_PCIE
scripts/config --enable CONFIG_IWLWIFI
scripts/config --enable CONFIG_IWLDVM
scripts/config --enable CONFIG_IWLMVM
# Enable IWLWIFI debug if requested
if [ "${IWLWIFI_DEBUG:-}" = "1" ]; then
    echo "Enabling IWLWIFI debug options..."
    scripts/config --enable CONFIG_IWLWIFI_DEBUG
    scripts/config --enable CONFIG_IWLWIFI_DEBUGFS
    scripts/config --enable CONFIG_IWLWIFI_DEVICE_TRACING
fi
scripts/config --enable CONFIG_PCI
scripts/config --enable CONFIG_MAC80211
#scripts/config --enable CONFIG_MAC80211_DEBUGFS
scripts/config --enable CONFIG_CFG80211
scripts/config --enable CONFIG_CFG80211_WEXT
scripts/config --enable CONFIG_WLAN
scripts/config --enable CONFIG_WIRELESS
scripts/config --enable CONFIG_NETDEVICES
scripts/config --enable CONFIG_NET
scripts/config --enable CONFIG_PACKET
scripts/config --enable CONFIG_UNIX
scripts/config --enable CONFIG_INET
scripts/config --enable CONFIG_IPV6
scripts/config --enable CONFIG_WIRELESS_EXT
scripts/config --enable CONFIG_LIB80211
scripts/config --enable CONFIG_CRYPTO_ARC4
scripts/config --enable CONFIG_CRYPTO_MICHAEL_MIC
scripts/config --enable CONFIG_CRYPTO_CCM
scripts/config --enable CONFIG_CRYPTO_GCM
scripts/config --enable CONFIG_CRYPTO_CMAC
scripts/config --enable CONFIG_MMC
scripts/config --enable CONFIG_MMC_SDHCI
scripts/config --enable CONFIG_MMC_SDHCI_PLTFM
scripts/config --enable CONFIG_MMC_SDHCI_IPROC
scripts/config --enable CONFIG_TMPFS
scripts/config --enable CONFIG_DEVTMPFS
scripts/config --enable CONFIG_DEVTMPFS_MOUNT

# Enable SSH and networking support
scripts/config --enable CONFIG_NETWORK_FILESYSTEMS
scripts/config --enable CONFIG_NFS_FS
scripts/config --enable CONFIG_ROOT_NFS
scripts/config --enable CONFIG_IP_PNP
scripts/config --enable CONFIG_IP_PNP_DHCP

# Regenerate config to resolve dependencies
make ARCH=arm64 olddefconfig

# Verify critical configurations are set
echo "Verifying kernel configuration..."
#CONFIG_CHECK="CONFIG_ARM64 CONFIG_BRCMFMAC CONFIG_IWLWIFI CONFIG_PCI CONFIG_MAC80211_DEBUGFS"
CONFIG_CHECK="CONFIG_ARM64 CONFIG_BRCMFMAC CONFIG_IWLWIFI CONFIG_PCI"
for config in $CONFIG_CHECK; do
    if grep -q "^${config}=y" .config; then
        echo "✓ $config is enabled"
    elif grep -q "^${config}=m" .config; then
        echo "✓ $config is enabled as module"
    else
        echo "✗ $config is NOT enabled!"
        exit 1
    fi
done

# Build kernel and modules
echo "Building kernel (this may take a while)..."
make ARCH=arm64 -j"$JOBS" Image modules dtbs

# Install modules to staging area
echo "Installing kernel modules..."
INSTALL_MOD_PATH="/build/rootfs" make ARCH=arm64 modules_install

# Copy kernel and device tree
echo "Installing kernel and device tree..."
mkdir -p /build/output/boot
cp arch/arm64/boot/Image /build/output/boot/kernel8.img
cp arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb /build/output/boot/
cp arch/arm64/boot/dts/overlays/*.dtbo /build/output/boot/overlays/ 2>/dev/null || true

echo "Kernel build completed successfully!"