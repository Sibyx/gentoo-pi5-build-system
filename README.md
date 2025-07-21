# Gentoo Raspberry Pi 5 Build System

A Docker-based cross-compilation build system for generating bootable Gentoo Linux SD card images for Raspberry Pi 5 with automatic WiFi configuration and SSH access.

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
| `KERNEL_URL`    | upstream 6.15.7 | Kernel source URL (tarball archive)         |
| `STAGE3_URL`    | Latest ARM64     | Custom Gentoo stage3 archive URL            |
| `IWLWIFI_DEBUG` | `0`             | Enable IWLWIFI debug options (1=enabled)    |

## Kernel Configuration

The build supports both upstream and Raspberry Pi kernels:

### Kernel Sources
- **Upstream**: Latest mainline kernel from kernel.org (default: 6.15.7)
- **Raspberry Pi**: Hardware-optimized kernel from raspberrypi/linux (6.15.y branch)

### Critical Features Enabled
- `CONFIG_ARM64`: ARM64 architecture support
- `CONFIG_BRCMFMAC`: Broadcom WiFi driver (built-in chip)
- `CONFIG_IWLWIFI`: Intel WiFi driver (AX210 PCIe card)
- `CONFIG_IWLWIFI_DEBUG`: Debug options (when `IWLWIFI_DEBUG=1`)
- `CONFIG_PCI`: PCI support for WiFi cards
- Standard networking and crypto modules for WiFi security

## Default Credentials

- **User**: `pi` / **Password**: `raspberry`
- **Root**: SSH login enabled
- **Hostname**: `rpi5-gentoo.local`
- **SSH**: Enabled on port 22

## Build Process

The build process consists of four sequential stages:

1. **Root Filesystem** (`build-rootfs.sh`):
   - Downloads Gentoo ARM64 musl stage3 archive
   - Extracts base filesystem structure
   - Prepares environment for configuration

2. **Kernel Build** (`build-kernel.sh`):
   - Downloads Linux kernel source
   - Configures for Raspberry Pi 5 with WiFi drivers
   - Builds kernel, modules, and device trees
   - Installs modules to rootfs
   - Verifies required configurations are enabled

3. **System Configuration** (`configure-system.sh`):
   - Configures base system (hostname, users, SSH)
   - Sets up WiFi auto-connect via wpa_supplicant
   - Creates systemd services and boot configuration
   - Enables required services

4. **Image Creation** (`create-image.sh`):
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
├── Dockerfile                 # Gentoo ARM64 build environment
├── build.sh                   # Host wrapper script with argument parsing
├── .github/
│   ├── workflows/
│   │   └── build-gentoo-rpi5.yml  # GitHub Actions CI/CD pipeline
│   └── ENVIRONMENT_SETUP.md   # GitHub environment configuration guide
├── scripts/
│   ├── build.sh               # Main build orchestrator (runs inside container)
│   ├── build-rootfs.sh        # Stage 1: Root filesystem extraction
│   ├── build-kernel.sh        # Stage 2: Kernel compilation
│   ├── configure-system.sh    # Stage 3: System configuration
│   └── create-image.sh        # Stage 4: Image creation
└── output/                    # Build artifacts (created during build)
    ├── gentoo-rpi5.img        # Raw SD card image
    └── gentoo-rpi5.img.xz     # Compressed image
```

## Advanced Usage

### Custom Kernel Sources

**Upstream kernel 6.15.7:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.15.7.tar.xz" \
  -e WIFI_SSID="YourNetwork" \
  -e WIFI_PASSWORD="YourPassword" \
  gentoo-rpi5-builder
```

**Raspberry Pi kernel 6.15.y branch:**
```bash
docker run --privileged --rm \
  -v $(pwd)/output:/build/output \
  -e KERNEL_URL="https://github.com/raspberrypi/linux/archive/refs/heads/rpi-6.15.y.tar.gz" \
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

## GitHub Actions CI/CD 🤖

This project includes automated CI/CD pipelines that build images using GitHub Actions with ARM runners:

- **Automatic builds**: Triggered on push to main/master branches
- **Manual dispatch**: Build specific kernel configurations on demand
- **Matrix builds**: Multiple kernel environments (linux-6.15.7, linux-raspi-6.15.y)
- **Artifact management**: Compressed images with checksums, 30-day retention

### Manual Build Dispatch
Go to the "Actions" tab and run "Build Gentoo Raspberry Pi 5 Images" workflow with:
- Custom kernel URL override
- Specific environments to build
- Debug logging options

See `.github/ENVIRONMENT_SETUP.md` for configuration details.

## Requirements

- **Host**: macOS/Linux with Docker (ARM64 recommended for best performance)
- **Target**: Raspberry Pi 5
- **Storage**: 8GB+ SD card
- **Network**: 2.4GHz or 5GHz WiFi
- **GitHub Actions**: ARM runners for CI/CD builds

## Contributing 🌸

Contributions are welcome! Sakura-chan in her cute dress would be delighted to see your improvements.

1. Fork the repository
2. Create your feature branch
3. Test your changes thoroughly
4. Submit a pull request with detailed description

## License

This project is provided as-is for educational and development purposes.