#!/bin/bash
set -euo pipefail

# Gentoo Pi5 QEMU Emulation
# Boot your built Gentoo image in QEMU for testing and development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

# Configuration
DEFAULT_MEMORY="4G"
DEFAULT_CORES="4"
SSH_PORT="2222"
MONITOR_PORT="4444"

show_usage() {
    cat << 'EOF'
🌸 Gentoo Pi5 QEMU Emulation

USAGE:
    ./emulate.sh [OPTIONS] [MODE]

MODES:
    boot        Boot the image normally (default)
    debug       Boot with verbose debugging output
    monitor     Boot with QEMU monitor access
    extract     Extract kernel and boot files for analysis

OPTIONS:
    -m, --memory SIZE    Set memory size (default: 4G)
    -c, --cores NUM      Set CPU cores (default: 4)
    -p, --ssh-port PORT  SSH forward port (default: 2222)
    --no-network         Disable network
    --snapshot           Run in snapshot mode (no disk changes)
    -h, --help           Show this help

EXAMPLES:
    ./emulate.sh                    # Simple boot
    ./emulate.sh debug              # Debug boot with verbose logging
    ./emulate.sh monitor            # Boot with monitor (telnet localhost 4444)
    ./emulate.sh --snapshot boot    # Boot without saving changes
    ./emulate.sh -m 8G -c 8 boot    # Boot with 8GB RAM and 8 cores

QEMU CONTROLS:
    Ctrl+A, X    Exit QEMU
    Ctrl+A, C    Switch to QEMU monitor console
    Ctrl+C       Send interrupt to guest

SSH ACCESS (when booted):
    ssh -p 2222 pi@localhost

REQUIREMENTS:
    - qemu-system-aarch64
    - Built Gentoo image in output/ directory
EOF
}

check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v qemu-system-aarch64 &> /dev/null; then
        print_error "QEMU ARM64 not found. Install with:"
        echo "  macOS:        brew install qemu"
        echo "  Ubuntu/Debian: sudo apt install qemu-system-arm"
        echo "  Arch Linux:   sudo pacman -S qemu-system-aarch64"
        echo "  RHEL/Fedora:  sudo dnf install qemu-system-aarch64"
        exit 1
    fi
    
    local image_file="$SCRIPT_DIR/output/gentoo-rpi5.img"
    local compressed_image="$SCRIPT_DIR/output/gentoo-rpi5.img.xz"
    
    if [[ ! -f "$image_file" ]] && [[ ! -f "$compressed_image" ]]; then
        print_error "No Gentoo image found. Build it first:"
        echo "  ./build.sh --ssid \"YourNetwork\" --password \"YourPassword\""
        exit 1
    fi
    
    # Decompress if needed
    if [[ ! -f "$image_file" ]] && [[ -f "$compressed_image" ]]; then
        print_status "Decompressing image..."
        unxz -k "$compressed_image"
    fi
    
    print_success "Requirements satisfied"
}

prepare_emulation_environment() {
    local emulation_dir="$SCRIPT_DIR/emulation"
    mkdir -p "$emulation_dir"
    
    local image_file="$SCRIPT_DIR/output/gentoo-rpi5.img"
    local work_image="$emulation_dir/gentoo-work.img"
    
    # Create working copy if it doesn't exist or is older than original
    if [[ ! -f "$work_image" ]] || [[ "$image_file" -nt "$work_image" ]]; then
        print_status "Creating working image copy..."
        cp "$image_file" "$work_image"
        print_success "Working image ready: $work_image"
    fi
    
    echo "$work_image"
}

extract_boot_files() {
    print_status "Extracting boot files for analysis..."
    
    local image_file="$(prepare_emulation_environment)"
    local emulation_dir="$SCRIPT_DIR/emulation"
    local extract_dir="$emulation_dir/extracted"
    
    mkdir -p "$extract_dir"
    
    # Mount image and extract files
    local loop_device
    loop_device=$(sudo losetup --show -fP "$image_file")
    
    # Create mount points
    local boot_mount="/tmp/gentoo-boot-$$"
    local root_mount="/tmp/gentoo-root-$$"
    sudo mkdir -p "$boot_mount" "$root_mount"
    
    # Mount partitions
    sudo mount "${loop_device}p1" "$boot_mount"
    sudo mount "${loop_device}p2" "$root_mount"
    
    # Extract key files
    print_status "Extracting boot files..."
    [[ -f "$boot_mount/kernel8.img" ]] && sudo cp "$boot_mount/kernel8.img" "$extract_dir/"
    [[ -f "$boot_mount/cmdline.txt" ]] && sudo cp "$boot_mount/cmdline.txt" "$extract_dir/"
    [[ -f "$boot_mount/config.txt" ]] && sudo cp "$boot_mount/config.txt" "$extract_dir/"
    [[ -f "$boot_mount/bcm2712-rpi-5-b.dtb" ]] && sudo cp "$boot_mount/bcm2712-rpi-5-b.dtb" "$extract_dir/"
    
    # Change ownership
    sudo chown -R "$(id -u):$(id -g)" "$extract_dir"
    
    # Cleanup
    sudo umount "$boot_mount" "$root_mount"
    sudo rmdir "$boot_mount" "$root_mount"
    sudo losetup -d "$loop_device"
    
    print_success "Boot files extracted to: $extract_dir"
    ls -la "$extract_dir"
}

boot_qemu() {
    local mode="$1"
    local memory="$2"
    local cores="$3"
    local ssh_port="$4"
    local use_network="$5"
    local snapshot="$6"
    
    local image_file="$(prepare_emulation_environment)"
    
    print_status "Starting QEMU emulation ($mode mode)..."
    print_info "Image: $(basename "$image_file")"
    print_info "Memory: $memory, Cores: $cores"
    [[ "$use_network" == "true" ]] && print_info "SSH: ssh -p $ssh_port pi@localhost"
    print_warning "Use Ctrl+A, X to exit QEMU"
    echo
    
    # Build QEMU command
    local qemu_args=(
        -M virt
        -cpu cortex-a76
        -smp "$cores"
        -m "$memory"
        -drive "file=$image_file,format=raw,if=virtio"
        -nographic
        -serial stdio
        -no-reboot
    )
    
    # Network configuration
    if [[ "$use_network" == "true" ]]; then
        qemu_args+=(
            -netdev "user,id=net0,hostfwd=tcp::$ssh_port-:22"
            -device "virtio-net-pci,netdev=net0"
        )
    fi
    
    # Snapshot mode
    [[ "$snapshot" == "true" ]] && qemu_args+=(-snapshot)
    
    # Mode-specific arguments
    case "$mode" in
        debug)
            qemu_args+=(
                -d guest_errors
                -append "root=/dev/vda2 rootfstype=ext4 console=ttyAMA0,115200 debug loglevel=7 systemd.log_level=debug systemd.log_target=console init=/sbin/init"
            )
            ;;
        monitor)
            qemu_args+=(
                -monitor "telnet:127.0.0.1:$MONITOR_PORT,server,nowait"
            )
            print_info "Monitor: telnet localhost $MONITOR_PORT"
            ;;
        boot)
            qemu_args+=(
                -append "root=/dev/vda2 rootfstype=ext4 console=ttyAMA0,115200 quiet"
            )
            ;;
    esac
    
    # Execute QEMU
    exec qemu-system-aarch64 "${qemu_args[@]}"
}

main() {
    local mode="boot"
    local memory="$DEFAULT_MEMORY"
    local cores="$DEFAULT_CORES"
    local ssh_port="$SSH_PORT"
    local use_network="true"
    local snapshot="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -m|--memory)
                memory="$2"
                shift 2
                ;;
            -c|--cores)
                cores="$2"
                shift 2
                ;;
            -p|--ssh-port)
                ssh_port="$2"
                shift 2
                ;;
            --no-network)
                use_network="false"
                shift
                ;;
            --snapshot)
                snapshot="true"
                shift
                ;;
            boot|debug|monitor)
                mode="$1"
                shift
                ;;
            extract)
                check_requirements
                extract_boot_files
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    check_requirements
    boot_qemu "$mode" "$memory" "$cores" "$ssh_port" "$use_network" "$snapshot"
}

main "$@"