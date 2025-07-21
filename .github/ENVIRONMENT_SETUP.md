# GitHub Environment Setup

This document describes how to set up GitHub environments for different kernel configurations.

## Environment Configuration

Each environment represents a different kernel configuration and contains the following variables:

### Environment Variables (vars)
- `WIFI_SSID` - Default WiFi network name
- `WIFI_COUNTRY` - WiFi country code (e.g., "US", "GB", "DE")
- `KERNEL_URL` - Kernel source URL (can be overridden via workflow_dispatch)
- `STAGE3_URL` - Custom Gentoo stage3 archive URL (optional)

### Environment Secrets
- `WIFI_PASSWORD` - Default WiFi password

## Example Environment Configurations

### linux-6.15.7
**Description:** Upstream Linux kernel 6.15.7

**Variables:**
- `WIFI_SSID`: `TestNetwork`
- `WIFI_COUNTRY`: `US` 
- `KERNEL_URL`: `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.15.7.tar.xz`

**Secrets:**
- `WIFI_PASSWORD`: `your-wifi-password`

### linux-raspi-6.15.y
**Description:** Raspberry Pi foundation kernel 6.15.y branch

**Variables:**
- `WIFI_SSID`: `RaspberryPi`
- `WIFI_COUNTRY`: `US`
- `KERNEL_URL`: `https://github.com/raspberrypi/linux/archive/rpi-6.15.y.tar.gz`

**Secrets:**
- `WIFI_PASSWORD`: `your-wifi-password`

### linux-6.12.1
**Description:** Upstream Linux kernel 6.12.1 (LTS)

**Variables:**
- `WIFI_SSID`: `StableNetwork`
- `WIFI_COUNTRY`: `US`
- `KERNEL_URL`: `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.1.tar.xz`

**Secrets:**
- `WIFI_PASSWORD`: `your-wifi-password`

## Setting up Environments

1. Go to your repository settings
2. Navigate to "Environments" in the left sidebar
3. Click "New environment"
4. Name it according to the kernel version (e.g., `linux-6.15.7`)
5. Add the required variables and secrets as listed above

## Manual Workflow Dispatch

When using workflow_dispatch, you can:

1. **Override KERNEL_URL**: Provide a custom kernel URL that overrides the environment default
2. **Select environments**: Specify which environments to build (comma-separated)
3. **Enable debug**: Turn on IWLWIFI debug logging

### Example Manual Dispatch

```
Environments: linux-6.15.7,linux-raspi-6.15.y
Kernel URL: https://github.com/torvalds/linux/archive/v6.16-rc1.tar.gz
Enable debug: true
```

This will build both environments but use the custom kernel URL instead of their defaults.

## Environment Naming Convention

Use the following pattern for environment names:
- `linux-X.Y.Z` - For upstream kernel versions
- `linux-raspi-X.Y.z` - For Raspberry Pi foundation kernels
- `linux-vendor-X.Y.z` - For vendor-specific kernels

Examples:
- `linux-6.15.7`
- `linux-6.12.1`
- `linux-raspi-6.15.y`
- `linux-ubuntu-6.8.0`