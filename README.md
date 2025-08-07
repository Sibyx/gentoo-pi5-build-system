# Gentoo Raspberry Pi 5 Build System 🌸

A comprehensive Docker-based cross-compilation system for building bootable Gentoo Linux images for Raspberry Pi 5. Features WiFi auto-configuration, SSH access, and QEMU emulation support for testing and development.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](docs/README.md)
[![QEMU Support](https://img.shields.io/badge/QEMU-supported-blue.svg)](#emulation)

## Features

- **Cross-compilation**: Built on Gentoo ARM64 container for macOS Apple Silicon hosts
- **Flexible kernel**: Configurable kernel source with WiFi drivers for built-in Broadcom and Intel AX210 PCIe cards
- **WiFi auto-connect**: Configurable via environment variables, connects automatically on first boot
- **SSH access**: Enabled by default with password and key-based authentication
- **Headless setup**: No manual configuration required after flashing

## Quick Start

### Option 1: Using the wrapper script (recommended)
```bash
./build.sh --ssid "YourWiFiNetwork" --password "YourWiFiPassword"
```

### Option 2: Direct Docker commands

1. **Build the Docker image:**
   ```bash
   docker build -t gentoo-rpi5-builder .
   ```

2. **Run the build with WiFi credentials:**
   
   **Universal command (works on all platforms):**
   ```bash
   docker run --privileged --rm \
     -v $(pwd)/output:/build/output \
     -e WIFI_SSID="YourWiFiNetwork" \
     -e WIFI_PASSWORD="YourWiFiPassword" \
     -e WIFI_COUNTRY="US" \
     gentoo-rpi5-builder
   ```
   
   **For Apple Silicon Macs (optimal performance):**
   ```bash
   docker run --privileged --rm \
     --platform linux/arm64 \
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

4. **Test with QEMU (optional):**
   ```bash
   # Install QEMU (if not installed)
   brew install qemu  # macOS
   # or: sudo apt install qemu-system-arm  # Ubuntu/Debian
   
   # Test boot in emulation
   ./emulate.sh
   
   # Debug boot issues
   ./emulate.sh debug
   ```

5. **Boot and connect:**
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
├── build.sh                   # 🔧 Main build script
├── emulate.sh                 # 🧪 QEMU emulation system
├── Dockerfile                 # 🐳 Gentoo ARM64 build environment
├── .github/
│   ├── workflows/
│   │   └── build-gentoo-rpi5.yml  # 🤖 CI/CD pipeline
│   └── ENVIRONMENT_SETUP.md   # ⚙️  GitHub environment setup
├── scripts/
│   ├── common.sh              # 🔨 Shared functions and utilities
│   ├── build.sh               # 📋 Build orchestrator (container)
│   ├── build-rootfs.sh        # 🏗️  Stage 1: Root filesystem
│   ├── build-kernel.sh        # ⚙️  Stage 2: Kernel compilation
│   ├── configure-system.sh    # 🔧 Stage 3: System configuration
│   └── create-image.sh        # 💾 Stage 4: Image creation
├── docs/
│   ├── README.md              # 📚 Documentation index
│   ├── QUICKSTART.md          # 🚀 Quick start guide
│   └── EMULATION.md           # 🧪 QEMU emulation guide
├── output/                    # 📁 Build artifacts (generated)
│   ├── gentoo-rpi5.img        # 💽 Raw SD card image
│   └── gentoo-rpi5.img.xz     # 📦 Compressed image
└── emulation/                 # 🧪 QEMU working files (generated)
    ├── gentoo-work.img        # 💾 Working copy for emulation
    └── extracted/             # 📂 Extracted boot files
        ├── kernel8.img        # ⚙️  ARM64 kernel
        ├── cmdline.txt        # 📝 Kernel parameters
        └── config.txt         # ⚙️  Boot configuration
```

## Docker Execution Details

### Required Docker Flags for Image Creation

The image creation process requires specific Docker privileges:

**Essential flags:**
- `--privileged` - Required for loop device operations and filesystem mounting
- `-v $(pwd)/output:/build/output` - Mount output directory for generated images

**Platform optimization:**
- `--platform linux/arm64` - Ensures ARM64 execution on Apple Silicon (optional but recommended)

**Alternative privilege flags (if --privileged doesn't work):**
- `--cap-add=SYS_ADMIN` - Administrative capabilities
- `--cap-add=MKNOD` - Device node creation
- `--device-cgroup-rule='c *:* rmw'` - Broad device access

### Troubleshooting Docker Issues

**If loop device creation fails:**
```bash
# Check if loop devices are available in container
docker run --privileged --rm gentoo-rpi5-builder ls -la /dev/loop*

# Check loop device support
docker run --privileged --rm gentoo-rpi5-builder losetup -f

# Test with maximum privileges (for macOS)
docker run --privileged --rm \
  --platform linux/arm64 \
  --cap-add=ALL \
  --security-opt apparmor=unconfined \
  --security-opt seccomp=unconfined \
  -v /dev:/dev \
  -v $(pwd)/output:/build/output \
  gentoo-rpi5-builder

# For macOS: Ensure Docker Desktop has privileged container support
# Docker Desktop > Settings > Docker Engine > Add: "features": {"buildkit": true}
```

**If permission errors occur:**
```bash
# Ensure output directory exists and is writable
mkdir -p output
chmod 755 output

# Run with user namespace mapping
docker run --privileged --rm \
  --userns=host \
  -v $(pwd)/output:/build/output \
  gentoo-rpi5-builder
```

**For Docker Desktop on macOS:**
```bash
# Ensure privileged containers are enabled in Docker Desktop
# Docker Desktop > Settings > Features in Development > Enable host networking

# Verify loop device support in container
docker run --privileged --rm --platform linux/arm64 \
  alpine:latest sh -c "ls -la /dev/loop* && losetup -f"

# Alternative: Use Lima, Colima, or OrbStack for better Linux compatibility
colima start --cpu 4 --memory 8 --arch aarch64
# or
orbstack
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

## Emulation

Test your built images without physical hardware using QEMU ARM64 emulation:

### Quick Start
```bash
# Test normal boot
./emulate.sh

# Debug boot issues
./emulate.sh debug

# Boot with monitor access
./emulate.sh monitor
```

### Installation
```bash
# macOS
brew install qemu

# Ubuntu/Debian
sudo apt install qemu-system-arm

# Arch Linux
sudo pacman -S qemu-system-aarch64
```

### Features
- **Multiple boot modes**: Normal, debug, and monitor modes
- **Network access**: SSH forwarding on port 2222
- **Snapshot support**: Test changes without affecting the base image
- **Boot file extraction**: Analyze kernel and configuration files
- **Performance tuning**: Configurable CPU cores and memory

### Usage Examples
```bash
# Build image with custom configuration
STAGE3_URL=https://distfiles.gentoo.org/releases/arm64/autobuilds/20250803T232237Z/stage3-arm64-musl-20250803T232237Z.tar.xz \
KERNEL_URL=https://github.com/raspberrypi/linux/archive/rpi-6.16.y.tar.gz \
./build.sh --ssid "Kapucinska 1 5 9" --password "smecarovni"

# Custom configuration
./emulate.sh -m 8G -c 8 boot

# Snapshot mode (no changes saved)
./emulate.sh --snapshot debug

# SSH access (when booted)
ssh -p 2222 pi@localhost

# Extract boot files for analysis
./emulate.sh extract
```

See [docs/EMULATION.md](docs/EMULATION.md) for comprehensive emulation documentation.

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

### Host System Requirements
- **macOS**: Intel or Apple Silicon with Docker Desktop
- **Linux**: x86_64 or ARM64 with Docker
- **Memory**: 8GB+ RAM recommended
- **Disk**: 15GB+ free space for build process
- **Docker**: Version 20.10+ with privileged container support

### Target Hardware
- **Device**: Raspberry Pi 5
- **Storage**: 8GB+ SD card (Class 10 or better)
- **Network**: 2.4GHz or 5GHz WiFi network

### Platform-Specific Notes

**macOS (Apple Silicon M1/M2/M3):**
- ✅ **Fully supported** - Native ARM64 compilation provides best performance
- Requires `--platform linux/arm64` flag for optimal performance
- Docker Desktop privileged containers must be enabled

**macOS (Intel):**
- ✅ **Supported** - Uses emulation (slower but functional)
- Same Docker flags as Apple Silicon

**Linux (x86_64/ARM64):**
- ✅ **Fully supported** - Native execution with best compatibility
- Standard `--privileged` flag usually sufficient
- Direct loop device access

**Key Point:** The build system uses a universal image creation method that works inside any Docker container on all host platforms including macOS. No special loop device management or host privileges are required.

**GitHub Actions:**
- ARM runners for CI/CD builds
- Automated matrix builds for multiple kernel versions

## Contributing 🌸

Contributions are welcome! Sakura-chan in her cute dress would be delighted to see your improvements.

1. Fork the repository
2. Create your feature branch
3. Test your changes thoroughly
4. Submit a pull request with detailed description

## License

This project is provided as-is for educational and development purposes.
