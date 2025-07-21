# GitHub Actions Workflows 🤖

This directory contains CI/CD workflows for automated Gentoo Raspberry Pi 5 image builds.

## Workflows

### `build-gentoo-rpi5.yml`
Main build workflow that creates bootable Gentoo images using ARM runners.

**Triggers:**
- Push to `main`/`master` branches (when scripts or Docker files change)
- Pull requests to `main`/`master` branches
- Manual dispatch (workflow_dispatch)

**Features:**
- 🏗️ **Matrix builds**: Multiple kernel environments simultaneously
- 🔧 **Manual dispatch**: Override kernel URL and select specific environments
- 📦 **Artifact management**: Compressed images with SHA256 checksums
- 🌸 **Kawaii reporting**: Sakura-chan approves successful builds!

## Manual Dispatch Usage

1. Go to the **Actions** tab in your repository
2. Select **"Build Gentoo Raspberry Pi 5 Images"** workflow  
3. Click **"Run workflow"**
4. Configure parameters:
   - **Kernel URL**: Override environment default (optional)
   - **Environments**: Comma-separated list (e.g., `linux-6.15.7,linux-raspi-6.15.y`)
   - **Enable Debug**: Turn on IWLWIFI debug logging

## Environment Setup

Create GitHub environments for different kernel configurations:

- `linux-6.15.7` - Upstream kernel 6.15.7
- `linux-raspi-6.15.y` - Raspberry Pi kernel 6.15.y branch

Each environment should contain:
- **Variables**: `WIFI_SSID`, `WIFI_COUNTRY`, `KERNEL_URL`, `STAGE3_URL`
- **Secrets**: `WIFI_PASSWORD`

See `.github/ENVIRONMENT_SETUP.md` for detailed configuration instructions.

## Build Artifacts

Successful builds generate:
- `gentoo-rpi5-{environment}-{sha}.img.xz` - Compressed SD card image
- `gentoo-rpi5-{environment}-{sha}.img.xz.sha256` - Checksum file
- Build logs and reports

Artifacts are retained for 30 days (images) and 14 days (logs).