# Quick Start Guide

Get your Gentoo Pi5 system up and running in under 10 minutes! 🌸

## Prerequisites

1. **Docker installed and running**
2. **WiFi network credentials**
3. **8GB+ available RAM**
4. **20GB+ free disk space**

## Step 1: Clone and Build

```bash
# Clone the repository
git clone <repository-url>
cd gentoo-pi5-build-system

# Build your image (replace with your WiFi credentials)
./build.sh --ssid "YourNetwork" --password "YourPassword"
```

**Build time**: ~60-90 minutes (depending on your system)

## Step 2: Test with Emulation

While your Pi5 is being set up, test the image:

```bash
# Install QEMU (if not installed)
# macOS:
brew install qemu

# Ubuntu/Debian:
sudo apt install qemu-system-arm

# Test boot in emulation
./emulate.sh
```

## Step 3: Flash to SD Card

```bash
# Find your SD card
lsblk  # Linux
diskutil list  # macOS

# Flash the image (replace /dev/sdX with your SD card)
sudo dd if=output/gentoo-rpi5.img of=/dev/sdX bs=1M status=progress

# Or use balenaEtcher GUI
```

## Step 4: Boot Your Pi5

1. Insert SD card into Raspberry Pi 5
2. Connect power
3. Wait ~3-5 minutes for first boot
4. System will automatically connect to your WiFi

## Step 5: Connect via SSH

```bash
# Find your Pi's IP address
nmap -sn 192.168.1.0/24  # Adjust subnet as needed

# SSH into your Pi
ssh pi@<pi-ip-address>
```

**Default credentials:**
- Username: `pi`
- Password: `raspberry`

## What's Next?

- **Change password**: `passwd pi`
- **Update system**: `emerge --sync && emerge -avuDN @world`
- **Install software**: `emerge <package-name>`
- **Configure services**: `systemctl enable/start <service>`

## Common Issues

### Build fails with "out of memory"
```bash
# Reduce parallel jobs
./build.sh --ssid "..." --password "..." --jobs 2
```

### Pi doesn't connect to WiFi
```bash
# Check WiFi credentials and country code
./build.sh --ssid "..." --password "..." --country "GB"
```

### Can't find Pi on network
```bash
# Connect monitor/keyboard to Pi and check:
ip addr show
systemctl status wpa_supplicant
```

## Help & Support

- **Documentation**: See `docs/` directory
- **Debug emulation**: `./emulate.sh debug`
- **Verbose build**: Add `--verbose` to build command
- **Issues**: Report on GitHub

---

🌸 **Happy Gentoo building!** ✨