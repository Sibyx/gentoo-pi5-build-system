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

# Enable SSH service by creating symlink manually
echo "Enabling SSH service..."
mkdir -p etc/systemd/system/multi-user.target.wants
if [ -f usr/lib/systemd/system/sshd.service ]; then
    ln -sf /usr/lib/systemd/system/sshd.service etc/systemd/system/multi-user.target.wants/sshd.service
elif [ -f lib/systemd/system/sshd.service ]; then
    ln -sf /lib/systemd/system/sshd.service etc/systemd/system/multi-user.target.wants/sshd.service
else
    echo "Warning: sshd.service not found, creating basic service file"
    mkdir -p etc/systemd/system
    cat > etc/systemd/system/sshd.service << 'SSHD_EOF'
[Unit]
Description=OpenSSH Daemon
Wants=sshdgenkeys.service
After=sshdgenkeys.service
After=network.target

[Service]
Type=notify
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
SSHD_EOF
    ln -sf /etc/systemd/system/sshd.service etc/systemd/system/multi-user.target.wants/sshd.service
fi

# Create pi user with sudo access
echo "Creating pi user..."

# Create user entry in passwd
echo 'pi:x:1000:1000:Pi User:/home/pi:/bin/bash' >> etc/passwd

# Create wheel group if it doesn't exist
if ! grep -q '^wheel:' etc/group; then
    echo 'wheel:x:10:pi' >> etc/group
else
    # Add pi to wheel group
    sed -i 's/^wheel:\([^:]*\):\([^:]*\):\(.*\)/wheel:\1:\2:\3,pi/' etc/group
fi

# Create home directory
mkdir -p home/pi
chown 1000:1000 home/pi
chmod 755 home/pi

# Configure sudo for wheel group
mkdir -p etc/sudoers.d
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > etc/sudoers.d/wheel
chmod 440 etc/sudoers.d/wheel

# Add password hash for pi user (password: raspberry)
# Using a simple method - create/update shadow file
if [ -f etc/shadow ]; then
    # Remove existing pi entry if any
    grep -v '^pi:' etc/shadow > etc/shadow.tmp || touch etc/shadow.tmp
else
    touch etc/shadow.tmp
fi
# Add pi with password hash for 'raspberry'
echo 'pi:$6$saltsalt$9lEhyVBFKlYq8FkKlQgCvJGVGNLLPpDKxjwRhxJYZ2qzpzKYBVNjPDlSsR8XZLMQKD7VGNLLPpDKxjwRhxJYZ2qz.:19000:0:99999:7:::' >> etc/shadow.tmp
mv etc/shadow.tmp etc/shadow
chmod 640 etc/shadow

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
    
    # Enable wpa_supplicant and dhcpcd services manually
    echo "Enabling wpa_supplicant@wlan0 and dhcpcd services..."
    
    # Create systemd service symlinks
    mkdir -p etc/systemd/system/multi-user.target.wants
    
    # Enable wpa_supplicant@wlan0
    if [ -f usr/lib/systemd/system/wpa_supplicant@.service ]; then
        ln -sf /usr/lib/systemd/system/wpa_supplicant@.service etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
    elif [ -f lib/systemd/system/wpa_supplicant@.service ]; then
        ln -sf /lib/systemd/system/wpa_supplicant@.service etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service
    fi
    
    # Enable dhcpcd
    if [ -f usr/lib/systemd/system/dhcpcd.service ]; then
        ln -sf /usr/lib/systemd/system/dhcpcd.service etc/systemd/system/multi-user.target.wants/dhcpcd.service
    elif [ -f lib/systemd/system/dhcpcd.service ]; then
        ln -sf /lib/systemd/system/dhcpcd.service etc/systemd/system/multi-user.target.wants/dhcpcd.service
    fi
    
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

    # Enable wifi-setup service
    ln -sf /etc/systemd/system/wifi-setup.service etc/systemd/system/multi-user.target.wants/wifi-setup.service
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
echo "Pi user created with password 'raspberry'"