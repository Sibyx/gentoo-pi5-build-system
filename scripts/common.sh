#!/bin/bash
# Common functions and utilities for Gentoo Pi5 build system

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Emoji and status functions
print_status() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_sakura() {
    echo -e "${PURPLE}🌸 $1${NC}"
}

# Logging functions
log_stage() {
    echo
    echo -e "${PURPLE}===========================================${NC}"
    echo -e "${PURPLE}🌸 Stage: $1${NC}"
    echo -e "${PURPLE}===========================================${NC}"
    echo
}

log_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

# Utility functions
check_file_exists() {
    local file="$1"
    local description="${2:-file}"
    
    if [[ ! -f "$file" ]]; then
        print_error "$description not found: $file"
        return 1
    fi
    return 0
}

check_dir_exists() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$dir" ]]; then
        print_error "$description not found: $dir"
        return 1
    fi
    return 0
}

check_command_exists() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command -v "$cmd" &> /dev/null; then
        print_error "Command '$cmd' not found. Install '$package' package."
        return 1
    fi
    return 0
}

# Size formatting
format_size() {
    local bytes="$1"
    
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# Progress indicator
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    
    # Cleanup any temporary files or mounts
    if [[ -n "${TEMP_MOUNTS:-}" ]]; then
        for mount in $TEMP_MOUNTS; do
            sudo umount "$mount" 2>/dev/null || true
        done
    fi
    
    if [[ -n "${TEMP_LOOP_DEVICES:-}" ]]; then
        for device in $TEMP_LOOP_DEVICES; do
            sudo losetup -d "$device" 2>/dev/null || true
        done
    fi
    
    exit $exit_code
}

# Set up cleanup trap
trap cleanup_on_exit EXIT

# System information
get_system_info() {
    echo "System Information:"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  CPU Cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')"
    
    if command -v free &> /dev/null; then
        echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    elif command -v vm_stat &> /dev/null; then
        echo "  Memory: $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)"GB"}')"
    fi
    
    echo "  Disk Space: $(df -h . | awk 'NR==2 {print $4}') available"
}

# Docker helpers
check_docker_running() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker."
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon not running. Please start Docker."
        return 1
    fi
    
    return 0
}

# Time helpers
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

get_build_id() {
    date '+%Y%m%d-%H%M%S'
}

# Validation helpers
validate_wifi_ssid() {
    local ssid="$1"
    
    if [[ -z "$ssid" ]]; then
        print_error "WiFi SSID cannot be empty"
        return 1
    fi
    
    if [[ ${#ssid} -gt 32 ]]; then
        print_error "WiFi SSID too long (max 32 characters)"
        return 1
    fi
    
    return 0
}

validate_wifi_password() {
    local password="$1"
    
    if [[ -z "$password" ]]; then
        print_error "WiFi password cannot be empty"
        return 1
    fi
    
    if [[ ${#password} -lt 8 ]]; then
        print_error "WiFi password too short (min 8 characters)"
        return 1
    fi
    
    if [[ ${#password} -gt 63 ]]; then
        print_error "WiFi password too long (max 63 characters)"
        return 1
    fi
    
    return 0
}

# Export all functions
set -a