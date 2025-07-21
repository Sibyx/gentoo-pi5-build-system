# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker-based cross-compilation build system for creating bootable Gentoo Linux SD card images for Raspberry Pi 5. The system builds from a Gentoo ARM64 container and produces complete images with WiFi auto-configuration and SSH access.

## Key Commands

### Building Images

**Quick build (using wrapper script):**
```bash
./build.sh --ssid "YourNetwork" --password "YourPassword"
```

**Direct Docker build:**
```bash
# Build the Docker image
docker build -t gentoo-rpi5-builder .

# Run the build process
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

### Environment Variables
- `WIFI_SSID`: WiFi network name (required for auto-connect)
- `WIFI_PASSWORD`: WiFi password  
- `WIFI_COUNTRY`: WiFi country code (default: US)
- `KERNEL_URL`: Custom kernel source URL (tarball or git)
- `STAGE3_URL`: Custom Gentoo stage3 archive URL
- `IWLWIFI_DEBUG`: Enable Intel WiFi debugging (0 or 1)

### Testing and Validation
No automated test suite - validation is done by:
1. Successful Docker build completion
2. Image file generation in `output/` directory
3. Physical testing on Raspberry Pi 5 hardware

## Architecture

The build process consists of four sequential stages orchestrated by `scripts/build.sh`:

### Stage 1: Root Filesystem (`build-rootfs.sh`)
- Downloads Gentoo ARM64 musl stage3 archive
- Extracts base filesystem structure
- Prepares environment for configuration

### Stage 2: Kernel Build (`build-kernel.sh`)
- Downloads Linux kernel source (default: upstream 6.6.47)
- Configures kernel for RPi5 with WiFi drivers:
  - `CONFIG_BRCMFMAC` (Broadcom built-in WiFi)
  - `CONFIG_IWLWIFI` (Intel AX210 PCIe cards)
  - ARM64 architecture support
- Cross-compiles kernel, modules, and device trees
- Installs modules to rootfs
- Verifies critical configurations are enabled

### Stage 3: System Configuration (`configure-system.sh`)
- Configures base system:
  - Hostname: `rpi5-gentoo.local`
  - Default user: `pi` (password: `raspberry`)
  - WiFi auto-connect via wpa_supplicant
  - SSH enabled with systemd services
  - DNS resolution configured
  - Boot configuration files

### Stage 4: Image Creation (`create-image.sh`)
- Creates 4GB partitioned SD card image
- Boot partition: FAT32 (512MB) with RPi firmware
- Root partition: ext4 with complete system
- Downloads and installs Raspberry Pi firmware
- Compresses final image with xz

## File Structure

```
├── Dockerfile              # Gentoo ARM64 build environment
├── build.sh                # Host wrapper script with argument parsing
├── scripts/
│   ├── build.sh            # Main orchestrator (runs inside container)
│   ├── build-rootfs.sh     # Stage 1: Root filesystem extraction
│   ├── build-kernel.sh     # Stage 2: Kernel compilation
│   ├── configure-system.sh # Stage 3: System configuration
│   └── create-image.sh     # Stage 4: Image creation
└── output/                 # Generated files (created during build)
```

## Docker Environment

- **Base**: `gentoo/stage3:arm64-musl`
- **Architecture**: Native ARM64 compilation
- **Required privileges**: `--privileged` for loop device access
- **Build tools**: gcc, kernel build tools, filesystem utilities
- **Runtime requirements**: 8GB+ disk space, network access

## Critical Implementation Details

### Loop Device Management
The image creation requires privileged container access for loop devices. Cleanup handlers in `scripts/build.sh` ensure proper unmounting and device detachment.

### WiFi Configuration
WiFi setup uses wpa_supplicant with systemd integration. Configuration files are generated dynamically in `configure-system.sh` based on environment variables.

### Kernel Source Flexibility
The system detects Raspberry Pi vs. upstream kernels by URL pattern matching and applies appropriate defconfig:
- RPi kernels: `bcm2712_defconfig`  
- Upstream kernels: `defconfig` + BCM2835 arch enablement

### Cross-Platform Support
Designed specifically for macOS Apple Silicon hosts cross-compiling ARM64 binaries. Native compilation eliminates emulation overhead.