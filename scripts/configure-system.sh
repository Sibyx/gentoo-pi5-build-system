#!/bin/bash
set -euo pipefail

echo "=== System Configuration ==="

ROOTFS_DIR="/build/rootfs"

# Ensure rootfs directory exists
if [ ! -d "$ROOTFS_DIR" ]; then
    echo "Error: Root filesystem directory not found at $ROOTFS_DIR"
    exit 1
fi

cd "$ROOTFS_DIR"

echo "Configuring system settings..."

# Set hostname
echo "rpi5-gentoo" > etc/hostname

# Configure hosts file
cat > etc/hosts << 'EOF'
127.0.0.1   localhost
127.0.1.1   rpi5-gentoo.local rpi5-gentoo
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Configure DNS
mkdir -p etc/systemd/resolved.conf.d
cat > etc/systemd/resolved.conf.d/dns.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
EOF

# Configure fstab
cat > etc/fstab << 'EOF'
/dev/mmcblk0p1  /boot           vfat    defaults        0       2
/dev/mmcblk0p2  /               ext4    defaults        0       1
tmpfs           /tmp            tmpfs   defaults        0       0
EOF

# Enable SSH
echo "Enabling SSH service..."
systemctl --root="$PWD" enable sshd

# Create pi user with sudo access
echo "Creating pi user..."
chroot . /bin/bash << 'CHROOT_EOF'
useradd -m -G wheel -s /bin/bash pi
echo 'pi:raspberry' | chpasswd
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
CHROOT_EOF

# Configure SSH for key-based auth and password auth
mkdir -p etc/ssh/sshd_config.d
cat > etc/ssh/sshd_config.d/rpi.conf << 'EOF'
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
EOF

# Configure WiFi if credentials provided
if [ -n "${WIFI_SSID:-}" ] && [ -n "${WIFI_PASSWORD:-}" ]; then
    echo "Configuring WiFi for SSID: $WIFI_SSID"
    
    # Create wpa_supplicant configuration
    mkdir -p etc/wpa_supplicant
    cat > etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-US}

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
    chmod 600 etc/wpa_supplicant/wpa_supplicant.conf
    
    # Enable wpa_supplicant and dhcpcd services
    systemctl --root="$PWD" enable wpa_supplicant@wlan0
    systemctl --root="$PWD" enable dhcpcd
    
    # Configure dhcpcd for wireless
    cat > etc/dhcpcd.conf << 'EOF'
# Inform the DHCP server of our hostname for DDNS.
hostname
# Use the hardware address of the interface for the Client ID.
clientid
# Persist interface configuration when dhcpcd exits.
persistent
# vendorclassid is set to blank to avoid sending the default of
# dhcpcd-<version>:<os>:<machine>:<platform>
vendorclassid
# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu
# A ServerID is required by RFC2131.
require dhcp_server_identifier
# Generate SLAAC address using the hardware address of the interface
slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
#slaac private

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
hostname

interface wlan0
    env wpa_supplicant_driver=nl80211,wext
EOF

    # Create systemd service for WiFi auto-connect
    mkdir -p etc/systemd/system
    cat > etc/systemd/system/wifi-setup.service << 'EOF'
[Unit]
Description=WiFi Setup Service
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create WiFi setup script
    mkdir -p usr/local/bin
    cat > usr/local/bin/wifi-setup.sh << 'EOF'
#!/bin/bash
# Ensure WiFi interface is up and connected
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
    wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf -D nl80211,wext
    dhcpcd wlan0
fi
EOF
    chmod +x usr/local/bin/wifi-setup.sh

    systemctl --root="$PWD" enable wifi-setup.service
fi

# Configure boot files
echo "Setting up boot configuration..."
mkdir -p boot
cat > boot/config.txt << 'EOF'
# Raspberry Pi 5 configuration
arm_64bit=1
kernel=kernel8.img

# Enable UART
enable_uart=1

# GPU memory split
gpu_mem=64

# WiFi/Bluetooth
dtparam=wifi=on
dtparam=bluetooth=on

# USB
dtoverlay=dwc2

# Audio
dtparam=audio=on

# Enable SSH
enable_ssh=1

# Camera
camera_auto_detect=1

# Display
display_auto_detect=1

# Enable I2C, SPI
dtparam=i2c_arm=on
dtparam=spi=on

# Device tree overlays directory
os_prefix=

# Firmware filename
start_file=start4.elf
fixup_file=fixup4.dat
EOF

cat > boot/cmdline.txt << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
EOF

echo "System configuration completed!"