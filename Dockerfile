FROM gentoo/stage3:arm64-musl

# Install required build tools and dependencies
RUN emerge-webrsync && \
    emerge --update --deep --newuse @world && \
    emerge sys-devel/bc \
           sys-devel/flex \
           sys-devel/bison \
           sys-apps/kmod \
           sys-fs/e2fsprogs \
           sys-fs/dosfstools \
           sys-apps/coreutils \
           app-arch/xz-utils \
           net-misc/wget \
           dev-vcs/git \
           sys-apps/util-linux \
           sys-block/parted \
           net-wireless/wpa_supplicant \
           net-misc/dhcpcd \
           net-misc/openssh \
           app-admin/sudo \
           sys-process/cronie

# Set up build environment (native ARM64 build)
ENV ARCH=arm64

# Build configuration environment variables (can be overridden at runtime)
ENV KERNEL_URL=""
ENV STAGE3_URL=""
ENV IWLWIFI_DEBUG="0"
ENV WIFI_SSID=""
ENV WIFI_PASSWORD=""
ENV WIFI_COUNTRY="US"

# Create working directories
WORKDIR /build
RUN mkdir -p /build/{kernel,rootfs,output,scripts}

# Copy build scripts
COPY scripts/ /build/scripts/
RUN chmod +x /build/scripts/*.sh

# Set the entrypoint
ENTRYPOINT ["/build/scripts/build.sh"]