# Gentoo Raspberry Pi 5 Build Server

Docker-based cross-compilation build server for generating Gentoo Linux SD card images for Raspberry Pi 5 with automatic 
WiFi configuration and SSH access.

## Features

- **Cross-compilation**: Built on Gentoo ARM64 container for macOS Apple Silicon hosts
- **Flexible kernel**: Configurable kernel source with WiFi drivers for built-in Broadcom and Intel AX210 PCIe cards
- **WiFi auto-connect**: Configurable via environment variables, connects automatically on first boot
- **SSH access**: Enabled by default with password and key-based authentication
- **Headless setup**: No manual configuration required after flashing

## Quick Start

1. **Build the Docker image:**
   ```bash
   docker build -t gentoo-rpi5-builder .
   ```

2. **Run the build with WiFi credentials:**
   ```bash
   docker run --privileged --rm \
     -v $(pwd)/output:/build/output \
     -e WIFI_SSID="YourWiFiNetwork" \
     -e WIFI_PASSWORD="YourWiFiPassword" \
     -e WIFI_COUNTRY="US" \
     gentoo-rpi5-builder
   ```

3. **Flash the resulting image:**
   ```bash
   # The output will be in ./output/gentoo-rpi5.img.xz
   dd if=output/gentoo-rpi5.img of=/dev/sdX bs=4M status=progress
   # or use balenaEtcher with the .xz file
   ```

4. **Boot and connect:**
   - Insert SD card into Raspberry Pi 5 and power on
   - The Pi will automatically connect to WiFi and be available at `rpi5-gentoo.local`
   - SSH access: `ssh pi@rpi5-gentoo.local` (password: `raspberry`)

## Environment Variables

| Variable        | Default         | Description                                 |
|-----------------|-----------------|---------------------------------------------|
| `WIFI_SSID`     | -               | WiFi network name (required for WiFi setup) |
| `WIFI_PASSWORD` | -               | WiFi password (required for WiFi setup)     |
| `WIFI_COUNTRY`  | `US`            | WiFi country code                           |
| `KERNEL_URL`    | upstream 6.6.47 | Kernel source URL (tarball archive)         |
| `STAGE3_URL`    | Jan 2025        | Custom Gentoo stage3 archive URL            |
| `IWLWIFI_DEBUG` | `0`             | Enable IWLWIFI debug options (1=enabled)    |

## Kernel Configuration

The build supports both upstream and Raspberry Pi kernels:

### Kernel Sources
- **Upstream**: Latest mainline kernel from kernel.org (default)
- **Raspberry Pi**: Hardware-optimized kernel from raspberrypi/linux

### Critical Features Enabled
- `CONFIG_ARM64`: ARM64 architecture support
- `CONFIG_BRCMFMAC`: Broadcom WiFi driver (built-in chip)
- `CONFIG_IWLWIFI`: Intel WiFi driver (AX210 PCIe card)
- `CONFIG_IWLWIFI_DEBUG`: Debug options (when `IWLWIFI_DEBUG=1`)
- `CONFIG_PCI`: PCI support for WiFi cards
- `CONFIG_MAC80211_DEBUGFS`: WiFi debugging support

## Default Credentials

- **User**: `pi` / **Password**: `raspberry`
- **Root**: SSH login enabled
- **Hostname**: `rpi5-gentoo.local`
- **SSH**: Enabled on port 22

## Build Process

The build process consists of three stages:

1. **Kernel Build** (`build-kernel.sh`):
   - Downloads Linux kernel source
   - Configures for Raspberry Pi 5 with WiFi drivers
   - Builds kernel, modules, and device trees
   - Verifies required configurations are enabled

2. **Root Filesystem** (`build-rootfs.sh`):
   - Downloads Gentoo ARM64 stage3
   - Configures system with WiFi auto-connect
   - Sets up users, SSH, and networking
   - Creates systemd services for WiFi setup

3. **Image Creation** (`create-image.sh`):
   - Creates partitioned SD card image
   - Installs root filesystem and kernel
   - Downloads Raspberry Pi firmware
   - Compresses final image

## Troubleshooting

### Build Issues
- Ensure Docker is running with `--privileged` flag for loop device access
- Check available disk space (build requires ~8GB)
- Verify network connectivity for downloading sources

### WiFi Connection Issues
- Verify SSID and password are correct
- Check country code matches your region
- Ensure WiFi network is 2.4GHz or 5GHz compatible
- Check kernel logs: `dmesg | grep -i wifi`

### SSH Access Issues
- Ensure SSH service is running: `systemctl status sshd`
- Check network connectivity: `ping rpi5-gentoo.local`
- Verify firewall settings if applicable

## File Structure

```
├── Dockerfile                 # Build environment setup
├── scripts/
│   ├── build.sh              # Main build orchestrator
│   ├── build-kernel.sh       # Kernel compilation
│   ├── build-rootfs.sh       # Root filesystem creation
│   └── create-image.sh       # SD image generation
└── output/                   # Build artifacts (created during build)
    ├── gentoo-rpi5.img       # Raw SD card image
    └── gentoo-rpi5.img.xz    # Compressed image
```

## Advanced Usage

### Custom Kernel Sources

**Upstream kernel 6.12.1:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.1.tar.xz" \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

**Raspberry Pi kernel 6.6.y branch:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e KERNEL_URL="https://github.com/raspberrypi/linux/archive/refs/heads/rpi-6.6.y.tar.gz" \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

**Enable IWLWIFI debugging:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e IWLWIFI_DEBUG="1" \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

**Custom Gentoo stage3:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e STAGE3_URL="https://distfiles.gentoo.org/releases/arm64/autobuilds/20250120T170309Z/stage3-arm64-musl-20250120T170309Z.tar.xz" \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

### Build Without WiFi Configuration
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  gentoo-rpi5-builder
```

### Mounting Additional Volumes
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -v $(pwd)/custom-configs:/build/custom \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

## Security Considerations

- Change default passwords after first boot
- Configure SSH key-based authentication
- Update system packages regularly
- Consider firewall configuration for production use

## Requirements

- **Host**: macOS with Apple Silicon and Docker
- **Target**: Raspberry Pi 5
- **Storage**: 8GB+ SD card
- **Network**: 2.4GHz or 5GHz WiFi

## License

This project is provided as-is for educational and development purposes.