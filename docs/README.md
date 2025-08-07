# Gentoo Pi5 Build System Documentation

Welcome to the comprehensive documentation for the Gentoo Raspberry Pi 5 build system! 🌸

## Overview

This build system creates bootable Gentoo Linux images for Raspberry Pi 5, featuring WiFi auto-configuration, SSH access, and QEMU emulation support for testing.

## Quick Navigation

### Getting Started
- **[Quick Start Guide](QUICKSTART.md)** - Get up and running in minutes
- **[Installation Requirements](REQUIREMENTS.md)** - What you need to build

### Building
- **[Build Guide](BUILD.md)** - Comprehensive building instructions
- **[Configuration Options](CONFIGURATION.md)** - Customize your build
- **[GitHub Actions](GITHUB_ACTIONS.md)** - Automated builds in CI/CD

### Testing & Development
- **[QEMU Emulation](EMULATION.md)** - Test your images virtually
- **[Debugging](DEBUGGING.md)** - Troubleshoot boot issues
- **[Development Workflow](DEVELOPMENT.md)** - Contributing to the project

### Reference
- **[Architecture](ARCHITECTURE.md)** - How the system works
- **[File Structure](FILE_STRUCTURE.md)** - Project organization
- **[API Reference](API.md)** - Script interfaces and functions

### Troubleshooting
- **[Common Issues](TROUBLESHOOTING.md)** - Solutions to frequent problems
- **[FAQ](FAQ.md)** - Frequently asked questions
- **[Performance Tuning](PERFORMANCE.md)** - Optimize your builds

## Features

✅ **Cross-platform builds** - Works on macOS, Linux, and GitHub Actions  
✅ **WiFi auto-configuration** - Connect automatically on first boot  
✅ **SSH access** - Remote access with key-based authentication  
✅ **QEMU emulation** - Test images without hardware  
✅ **Multiple kernel sources** - Raspberry Pi and upstream kernels  
✅ **Automated CI/CD** - GitHub Actions integration  
✅ **Debug support** - Verbose logging and troubleshooting tools  

## Quick Commands

```bash
# Build a basic image
./build.sh --ssid "MyNetwork" --password "MyPassword"

# Build with custom kernel
./build.sh --ssid "MyNetwork" --password "MyPassword" --kernel-url "https://..."

# Test in QEMU
./emulate.sh

# Debug boot issues
./emulate.sh debug

# Extract boot files for analysis
./emulate.sh extract
```

## System Requirements

### Host System
- **Docker**: For containerized builds
- **8GB+ RAM**: For kernel compilation
- **20GB+ Storage**: For build artifacts
- **Network**: For downloading sources

### Optional (for emulation)
- **QEMU**: ARM64 system emulation
- **4GB+ RAM**: For guest system

### Supported Platforms
- macOS (Intel/Apple Silicon)
- Linux (x86_64/ARM64)
- GitHub Actions (ARM64 runners)

## Project Structure

```
gentoo-pi5-build-system/
├── build.sh              # Main build wrapper
├── emulate.sh             # QEMU emulation system
├── Dockerfile             # Build environment
├── scripts/               # Build stage scripts
├── docs/                  # Documentation
├── .github/workflows/     # CI/CD automation
└── output/               # Generated images
```

## Contributing

We welcome contributions! See our [Development Guide](DEVELOPMENT.md) for:
- Setting up development environment
- Code style guidelines
- Testing procedures
- Submission process

## Support

- **Issues**: Report bugs and feature requests on GitHub
- **Discussions**: Join community discussions
- **Documentation**: Comprehensive guides in `docs/`

## License

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.

---

🌸 **Sakura-chan blesses your Gentoo builds with kawaii energy!** ✨