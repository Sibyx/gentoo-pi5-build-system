# QEMU Emulation Guide

This guide explains how to use QEMU to emulate your built Gentoo Pi5 system for testing, debugging, and development.

## Overview

The emulation system provides several modes for running your Gentoo Pi5 image:

- **Boot Mode**: Normal system boot for testing
- **Debug Mode**: Verbose logging for troubleshooting boot issues
- **Monitor Mode**: Advanced debugging with QEMU monitor access
- **Extract Mode**: Extract boot files for analysis

## Quick Start

```bash
# Build your Gentoo image first
./build.sh --ssid "YourNetwork" --password "YourPassword"

# Boot in emulation
./emulate.sh

# Boot with debug logging
./emulate.sh debug

# Boot with QEMU monitor access
./emulate.sh monitor
```

## Installation Requirements

### macOS
```bash
brew install qemu
```

### Ubuntu/Debian
```bash
sudo apt install qemu-system-arm
```

### Arch Linux
```bash
sudo pacman -S qemu-system-aarch64
```

### RHEL/Fedora
```bash
sudo dnf install qemu-system-aarch64
```

## Usage

### Basic Commands

```bash
./emulate.sh [OPTIONS] [MODE]
```

### Modes

| Mode | Description |
|------|-------------|
| `boot` | Normal boot (default) |
| `debug` | Boot with verbose debug output |
| `monitor` | Boot with QEMU monitor on port 4444 |
| `extract` | Extract kernel and boot files |

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-m, --memory SIZE` | Set memory size | 4G |
| `-c, --cores NUM` | Set CPU cores | 4 |
| `-p, --ssh-port PORT` | SSH forward port | 2222 |
| `--no-network` | Disable network | - |
| `--snapshot` | Run without saving changes | - |

### Examples

```bash
# Standard boot
./emulate.sh

# Debug boot with 8GB RAM
./emulate.sh -m 8G debug

# Boot in snapshot mode (no changes saved)
./emulate.sh --snapshot boot

# Boot with custom SSH port
./emulate.sh -p 3333 boot

# Boot without network
./emulate.sh --no-network boot

# Extract boot files for analysis
./emulate.sh extract
```

## QEMU Controls

While the emulated system is running:

| Key Combination | Action |
|-----------------|--------|
| `Ctrl+A, X` | Exit QEMU |
| `Ctrl+A, C` | Switch to QEMU monitor console |
| `Ctrl+C` | Send interrupt to guest system |

## Network Access

When the system boots successfully, you can SSH into it:

```bash
ssh -p 2222 pi@localhost
```

**Default credentials:**
- Username: `pi`
- Password: `raspberry`

## Debugging Boot Issues

### Enable Debug Mode

```bash
./emulate.sh debug
```

This enables:
- Verbose kernel logging (`loglevel=7`)
- SystemD debug output
- Guest error logging in QEMU

### Common Boot Issues

#### 1. Kernel Panic
**Symptoms:** System crashes during kernel initialization
**Solutions:**
- Check kernel configuration in extracted files
- Verify ARM64 compatibility
- Check device tree blob

#### 2. Root Filesystem Not Found
**Symptoms:** "Cannot find root filesystem" error
**Solutions:**
- Verify partition layout with `./emulate.sh extract`
- Check `/dev/vda2` mounting in debug output
- Validate filesystem integrity

#### 3. SystemD Issues
**Symptoms:** SystemD fails to start services
**Solutions:**
- Check SystemD configuration in debug output
- Verify service file syntax
- Check file permissions

### Advanced Debugging with Monitor Mode

```bash
./emulate.sh monitor
```

Then connect to the QEMU monitor:
```bash
telnet localhost 4444
```

**Useful monitor commands:**
```
info registers    # Show CPU registers
info memory       # Show memory mapping
info block        # Show block devices
system_reset      # Reset the system
quit              # Exit QEMU
```

### Extracting Boot Files

```bash
./emulate.sh extract
```

This extracts:
- `kernel8.img` - ARM64 kernel
- `cmdline.txt` - Kernel command line
- `config.txt` - Boot configuration
- `bcm2712-rpi-5-b.dtb` - Device tree blob

Files are extracted to `emulation/extracted/` for analysis.

## Troubleshooting

### QEMU Not Found
```bash
# Check if QEMU is installed
which qemu-system-aarch64

# Install if missing (macOS)
brew install qemu
```

### Image Not Found
```bash
# Check if image exists
ls -la output/gentoo-rpi5.img*

# Build if missing
./build.sh --ssid "YourNetwork" --password "YourPassword"
```

### Permission Errors
The emulation system may need sudo access for:
- Mounting loop devices
- Extracting boot files

Ensure your user has sudo privileges.

### Performance Issues
- Increase CPU cores: `./emulate.sh -c 8`
- Increase memory: `./emulate.sh -m 8G`
- Use snapshot mode for faster boot: `./emulate.sh --snapshot`

## File Structure

```
emulation/
├── gentoo-work.img       # Working copy of the image
└── extracted/            # Extracted boot files
    ├── kernel8.img       # ARM64 kernel
    ├── cmdline.txt       # Kernel parameters
    ├── config.txt        # Boot configuration
    └── bcm2712-rpi-5-b.dtb  # Device tree
```

## Integration with Development

### Testing Changes
1. Modify system in snapshot mode:
   ```bash
   ./emulate.sh --snapshot debug
   ```
2. Test changes without affecting the base image
3. Rebuild image with fixes if needed

### Automated Testing
The emulation system can be integrated into CI/CD:
```bash
# Boot test
timeout 300 ./emulate.sh --no-network boot

# Extract and verify boot files
./emulate.sh extract
test -f emulation/extracted/kernel8.img
```

## Performance Notes

- QEMU ARM64 emulation is slower than native execution
- Typical boot time: 2-5 minutes (depending on host system)
- Network performance may be limited
- Use snapshot mode for faster repeated testing

## See Also

- [Building Guide](BUILD.md) - How to build the image
- [Architecture](ARCHITECTURE.md) - System architecture overview
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions