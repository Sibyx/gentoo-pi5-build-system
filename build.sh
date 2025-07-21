#!/bin/bash
set -euo pipefail

# Gentoo Raspberry Pi 5 Image Builder
# Quick build script for macOS hosts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="gentoo-rpi5-builder"

# Default values
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PASSWORD="${WIFI_PASSWORD:-}"
WIFI_COUNTRY="${WIFI_COUNTRY:-US}"
OUTPUT_DIR="${SCRIPT_DIR}/output"
KERNEL_URL="${KERNEL_URL:-}"
STAGE3_URL="${STAGE3_URL:-}"
IWLWIFI_DEBUG="${IWLWIFI_DEBUG:-0}"

# Parse command line arguments
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --ssid SSID           WiFi network name"
    echo "  -p, --password PASSWORD   WiFi password"
    echo "  -c, --country COUNTRY     WiFi country code (default: US)"
    echo "  -o, --output DIR          Output directory (default: ./output)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  WIFI_SSID                WiFi network name"
    echo "  WIFI_PASSWORD            WiFi password"
    echo "  WIFI_COUNTRY             WiFi country code"
    echo "  KERNEL_URL               Kernel URL (archive or git repo)"
    echo "  STAGE3_URL               Custom Gentoo stage3 URL"
    echo "  IWLWIFI_DEBUG            Enable IWLWIFI debug: 1 or 0 (default: 0)"
    echo ""
    echo "Examples:"
    echo "  $0 --ssid MyNetwork --password MyPassword"
    echo "  WIFI_SSID=MyNetwork WIFI_PASSWORD=MyPassword $0"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--ssid)
            WIFI_SSID="$2"
            shift 2
            ;;
        -p|--password)
            WIFI_PASSWORD="$2"
            shift 2
            ;;
        -c|--country)
            WIFI_COUNTRY="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "=== Gentoo Raspberry Pi 5 Image Builder ==="
echo "Output directory: $OUTPUT_DIR"

if [ -n "$WIFI_SSID" ]; then
    echo "WiFi SSID: $WIFI_SSID"
    echo "WiFi Country: $WIFI_COUNTRY"
else
    echo "WiFi: Not configured (no SSID provided)"
fi

echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running or not accessible"
    exit 1
fi

# Build Docker image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

# Run the build
echo ""
echo "Starting build process..."
docker run --privileged --rm \
    -v "$OUTPUT_DIR:/build/output" \
    -e "WIFI_SSID=$WIFI_SSID" \
    -e "WIFI_PASSWORD=$WIFI_PASSWORD" \
    -e "WIFI_COUNTRY=$WIFI_COUNTRY" \
    -e "KERNEL_URL=$KERNEL_URL" \
    -e "STAGE3_URL=$STAGE3_URL" \
    -e "IWLWIFI_DEBUG=$IWLWIFI_DEBUG" \
    "$IMAGE_NAME"

echo ""
echo "=== Build Complete ==="
echo "Output files:"
ls -lh "$OUTPUT_DIR"/*.img* 2>/dev/null || echo "No image files found in output directory"

echo ""
echo "To flash the image:"
echo "  dd if=$OUTPUT_DIR/gentoo-rpi5.img of=/dev/sdX bs=4M status=progress"
echo "  or use balenaEtcher with gentoo-rpi5.img.xz"
echo ""
echo "Default login: pi/raspberry"
echo "SSH access: ssh pi@rpi5-gentoo.local"