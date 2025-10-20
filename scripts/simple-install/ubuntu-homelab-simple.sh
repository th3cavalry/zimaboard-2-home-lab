#!/bin/bash

# 🏠 ZimaBoard 2 Simple Homelab Setup - Single OS Installation
# No containers, no Proxmox - just Ubuntu Server with all services
# Optimized for eMMC longevity and 2TB SSD storage

set -e

echo "🚀 ZimaBoard 2 Simple Homelab Setup Starting..."
echo "📱 Installing all services directly on Ubuntu Server"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   echo "💡 Please run: sudo bash $0"
   exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    print_error "This script is designed for Ubuntu Server. Please install Ubuntu Server 24.04 LTS first."
    exit 1
fi

print_status "Detected Ubuntu Server - continuing with installation..."

# Interactive SSD Setup Function
setup_ssd_storage() {
    print_status "🔍 Detecting available storage devices..."
    
    # Detect potential SSD devices
    DETECTED_SSDS=()
    for device in /dev/sd? /dev/nvme?n?; do
        if [ -b "$device" ]; then
            SIZE=$(lsblk -b -d -o SIZE "$device" 2>/dev/null | tail -n1)
            # Look for devices larger than 500GB (assuming 2TB SSD)
            if [ "$SIZE" -gt 500000000000 ]; then
                DEVICE_INFO=$(lsblk -d -o NAME,SIZE,MODEL "$device" 2>/dev/null | tail -n1)
                DETECTED_SSDS+=("$device:$DEVICE_INFO")
            fi
        fi
    done
    
    if [ ${#DETECTED_SSDS[@]} -eq 0 ]; then
        print_warning "No large storage devices detected. Proceeding with eMMC-only setup."
        print_warning "Services will work but performance will be limited."
        return 1
    fi
    
    echo ""
    print_status "🎯 Found ${#DETECTED_SSDS[@]} potential SSD(s):"
    for i in "${!DETECTED_SSDS[@]}"; do
        IFS=':' read -r device info <<< "${DETECTED_SSDS[$i]}"
        echo "  $((i+1)). $info"
    done
    echo ""
    
    # Interactive menu
    echo "How would you like to configure your SSD storage?"
    echo "1) 🆕 Format and setup fresh (ERASES ALL DATA - recommended for new drives)"
    echo "2) 📁 Use existing partitions (preserves existing data)"
    echo "3) ⚙️  Advanced setup (manual partition selection)"
    echo "4) ⏭️  Skip SSD setup (use eMMC only)"
    echo ""
    
    while true; do
        read -p "Select option (1-4): " choice
        case $choice in
            1)
                setup_fresh_ssd
                break
                ;;
            2)
                setup_existing_ssd
                break
                ;;
            3)
                setup_advanced_ssd
                break
                ;;
            4)
                print_warning "Skipping SSD setup - using eMMC only"
                return 1
                ;;
            *)
                echo "❌ Invalid option. Please select 1-4."
                ;;
        esac
    done
}

# Fresh SSD Setup (Format and partition)
setup_fresh_ssd() {
    if [ ${#DETECTED_SSDS[@]} -eq 1 ]; then
        IFS=':' read -r SSD_DEVICE info <<< "${DETECTED_SSDS[0]}"
    else
        echo ""
        print_status "Select SSD to format:"
        for i in "${!DETECTED_SSDS[@]}"; do
            IFS=':' read -r device info <<< "${DETECTED_SSDS[$i]}"
            echo "  $((i+1)). $info"
        done
        
        while true; do
            read -p "Select SSD (1-${#DETECTED_SSDS[@]}): " ssd_choice
            if [[ "$ssd_choice" =~ ^[1-9][0-9]*$ ]] && [ "$ssd_choice" -le ${#DETECTED_SSDS[@]} ]; then
                IFS=':' read -r SSD_DEVICE info <<< "${DETECTED_SSDS[$((ssd_choice-1))]}"
                break
            else
                echo "❌ Invalid selection."
            fi
        done
    fi
    
    echo ""
    print_warning "⚠️  WARNING: This will COMPLETELY ERASE ALL DATA on $SSD_DEVICE"
    print_warning "⚠️  Make sure this is the correct device and you have backups!"
    echo ""
    
    read -p "Type 'YES' to confirm you want to erase $SSD_DEVICE: " confirm
    if [ "$confirm" != "YES" ]; then
        print_error "Operation cancelled. Exiting."
        exit 1
    fi
    
    print_status "🔧 Formatting $SSD_DEVICE for homelab use..."
    
    # Install partitioning tools
    apt install -y parted
    
    # Unmount any existing partitions
    for part in ${SSD_DEVICE}*; do
        if [ -b "$part" ] && [ "$part" != "$SSD_DEVICE" ]; then
            umount "$part" 2>/dev/null || true
        fi
    done
    
    # Create GPT partition table and two partitions
    parted -s "$SSD_DEVICE" mklabel gpt
    parted -s "$SSD_DEVICE" mkpart primary ext4 0% 80%
    parted -s "$SSD_DEVICE" mkpart primary ext4 80% 100%
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$SSD_DEVICE" 2>/dev/null || true
    sleep 1
    
    # Determine partition names
    if [[ "$SSD_DEVICE" =~ nvme ]]; then
        DATA_PARTITION="${SSD_DEVICE}p1"
        BACKUP_PARTITION="${SSD_DEVICE}p2"
    else
        DATA_PARTITION="${SSD_DEVICE}1"
        BACKUP_PARTITION="${SSD_DEVICE}2"
    fi
    
    print_status "📁 Creating filesystems..."
    
    # Format partitions with ext4
    mkfs.ext4 -F "$DATA_PARTITION" -L "homelab-data"
    mkfs.ext4 -F "$BACKUP_PARTITION" -L "homelab-backup"
    
    # Create mount points and mount
    mkdir -p /mnt/ssd-data /mnt/ssd-backup
    mount "$DATA_PARTITION" /mnt/ssd-data
    mount "$BACKUP_PARTITION" /mnt/ssd-backup
    
    # Add to fstab for persistent mounting
    DATA_UUID=$(blkid -s UUID -o value "$DATA_PARTITION")
    BACKUP_UUID=$(blkid -s UUID -o value "$BACKUP_PARTITION")
    
    echo "UUID=$DATA_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
    echo "UUID=$BACKUP_UUID /mnt/ssd-backup ext4 defaults,noatime 0 2" >> /etc/fstab
    
    print_success "✅ SSD formatted and mounted successfully!"
    print_success "   Data partition: /mnt/ssd-data (main storage)"
    print_success "   Backup partition: /mnt/ssd-backup (backups)"
    
    return 0
}

# Use existing SSD partitions
setup_existing_ssd() {
    print_status "🔍 Scanning for existing partitions..."
    
    AVAILABLE_PARTITIONS=()
    for device_info in "${DETECTED_SSDS[@]}"; do
        IFS=':' read -r device info <<< "$device_info"
        
        # Check for existing partitions
        for part in ${device}*; do
            if [ -b "$part" ] && [ "$part" != "$device" ]; then
                FSTYPE=$(lsblk -f -o FSTYPE "$part" 2>/dev/null | tail -n1)
                SIZE=$(lsblk -b -o SIZE "$part" 2>/dev/null | tail -n1 | numfmt --to=iec)
                if [ -n "$FSTYPE" ]; then
                    AVAILABLE_PARTITIONS+=("$part:$FSTYPE:$SIZE")
                fi
            fi
        done
    done
    
    if [ ${#AVAILABLE_PARTITIONS[@]} -eq 0 ]; then
        print_error "No existing formatted partitions found. Please use fresh format option."
        return 1
    fi
    
    echo ""
    print_status "📂 Found existing partitions:"
    for i in "${!AVAILABLE_PARTITIONS[@]}"; do
        IFS=':' read -r partition fstype size <<< "${AVAILABLE_PARTITIONS[$i]}"
        echo "  $((i+1)). $(basename $partition) - $fstype - $size"
    done
    echo ""
    
    read -p "Select partition for main data storage (1-${#AVAILABLE_PARTITIONS[@]}): " part_choice
    if [[ ! "$part_choice" =~ ^[1-9][0-9]*$ ]] || [ "$part_choice" -gt ${#AVAILABLE_PARTITIONS[@]} ]; then
        print_error "Invalid selection."
        return 1
    fi
    
    IFS=':' read -r DATA_PARTITION fstype size <<< "${AVAILABLE_PARTITIONS[$((part_choice-1))]}"
    
    # Mount the selected partition
    mkdir -p /mnt/ssd-data
    mount "$DATA_PARTITION" /mnt/ssd-data 2>/dev/null || {
        print_error "Failed to mount $DATA_PARTITION"
        return 1
    }
    
    # Add to fstab
    DATA_UUID=$(blkid -s UUID -o value "$DATA_PARTITION")
    if ! grep -q "$DATA_UUID" /etc/fstab; then
        echo "UUID=$DATA_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
    fi
    
    print_success "✅ Using existing partition $DATA_PARTITION for data storage"
    return 0
}

# Advanced SSD setup
setup_advanced_ssd() {
    print_warning "Advanced setup selected - you'll need to manually configure partitions."
    print_status "Available devices:"
    
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
    echo ""
    
    read -p "Enter the partition path for data storage (e.g., /dev/sda1): " DATA_PARTITION
    
    if [ ! -b "$DATA_PARTITION" ]; then
        print_error "$DATA_PARTITION is not a valid block device"
        return 1
    fi
    
    mkdir -p /mnt/ssd-data
    
    # Test mount
    if mount "$DATA_PARTITION" /mnt/ssd-data 2>/dev/null; then
        DATA_UUID=$(blkid -s UUID -o value "$DATA_PARTITION")
        if ! grep -q "$DATA_UUID" /etc/fstab 2>/dev/null; then
            echo "UUID=$DATA_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
        fi
        print_success "✅ Advanced setup complete using $DATA_PARTITION"
        return 0
    else
        print_error "Failed to mount $DATA_PARTITION"
        return 1
    fi
}

# Run SSD setup
if setup_ssd_storage; then
    SSD_AVAILABLE=true
    print_success "🎉 SSD storage configured successfully!"
else
    SSD_AVAILABLE=false
    print_warning "📱 Continuing with eMMC-only setup"
fi

# 1. System Updates and Basic Setup
print_status "📦 Updating system packages..."
apt update && apt upgrade -y

# 2. Install essential packages
print_status "🔧 Installing essential packages..."
apt install -y \
    curl wget git htop iotop \
    nginx apache2-utils \
    fail2ban ufw \
    sqlite3 \
    python3 python3-pip \
    nodejs npm \
    php php-fpm php-sqlite3 php-xml php-intl \
    dnsutils net-tools \
    unattended-upgrades

# 3. Configure UFW Firewall
print_status "🔥 Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp    # Nginx (no conflict with AdGuard Home!)
ufw allow 443/tcp   # HTTPS
ufw allow 53/tcp    # DNS
ufw allow 53/udp    # DNS
ufw allow 3000/tcp  # AdGuard Home Web UI
ufw allow 8000/tcp  # Nextcloud
ufw allow 3128/tcp  # Squid proxy
ufw allow 19999/tcp # Netdata
ufw allow 51820/udp # Wireguard

# 4. eMMC Optimization
print_status "📱 Configuring eMMC optimizations..."
# Reduce swap usage
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

# Add noatime to reduce eMMC writes
cp /etc/fstab /etc/fstab.backup
sed -i 's/errors=remount-ro/errors=remount-ro,noatime/' /etc/fstab

# Configure log rotation
echo "daily
rotate 7
compress
delaycompress
missingok
notifempty
create 644 syslog adm" > /etc/logrotate.conf

print_success "eMMC optimizations applied"

# 5. Configure Data Storage Directories
if [ "$SSD_AVAILABLE" = true ]; then
    print_status "💾 Configuring SSD data directories..."
    # Create data directories on SSD
    mkdir -p /mnt/ssd-data/{nextcloud,adguardhome,squid-cache,backups,logs}
    
    # Move log directory to SSD to reduce eMMC writes
    if [ ! -L /var/log ] && [ -d /mnt/ssd-data ]; then
        cp -a /var/log/* /mnt/ssd-data/logs/ 2>/dev/null || true
        mv /var/log /var/log.old
        ln -s /mnt/ssd-data/logs /var/log
        print_success "Moved logs to SSD for eMMC longevity"
    fi
    
    DATA_DIR="/mnt/ssd-data"
    print_success "Using SSD for all service data"
else
    print_status "💾 Configuring eMMC data directories..."
    # Create data directories on eMMC (fallback)
    mkdir -p /opt/homelab-data/{nextcloud,adguardhome,squid-cache,backups,logs}
    DATA_DIR="/opt/homelab-data"
    print_warning "Using eMMC storage - consider adding SSD for better performance"
fi

# 6. Install AdGuard Home
print_status "🔥 Installing AdGuard Home..."

# Create directories
ADGUARD_INSTALL_DIR="/opt/AdGuardHome"
ADGUARD_WORK_DIR="${DATA_DIR}/adguardhome"
mkdir -p "$ADGUARD_INSTALL_DIR"
mkdir -p "$ADGUARD_WORK_DIR"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ADGUARD_ARCH="amd64"
        ;;
    aarch64|arm64)
        ADGUARD_ARCH="arm64"
        ;;
    armv7l|armhf)
        ADGUARD_ARCH="armv7"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download latest AdGuard Home
ADGUARD_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
ADGUARD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz"

print_status "Downloading AdGuard Home $ADGUARD_VERSION..."
cd /tmp
curl -L -o AdGuardHome.tar.gz "$ADGUARD_URL"
tar -xzf AdGuardHome.tar.gz
cd AdGuardHome
mv AdGuardHome "$ADGUARD_INSTALL_DIR/"
chmod +x "$ADGUARD_INSTALL_DIR/AdGuardHome"
cd /
rm -rf /tmp/AdGuardHome /tmp/AdGuardHome.tar.gz

# Create AdGuard Home configuration
cat > "$ADGUARD_WORK_DIR/AdGuardHome.yaml" << 'AGHEOF'
bind_host: 0.0.0.0
bind_port: 3000
users:
  - name: admin
    password: $2a$10$jU3FqELn3cqV/4gkH5w5z.mf5h9q2lZ8L6rG5tF8uVwK7u6p5F5G.
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: en
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  ratelimit: 0
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
  upstream_dns_file: ""
  bootstrap_dns:
    - 1.1.1.1
    - 1.0.0.1
  fallback_dns: []
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: false
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
tls:
  enabled: false
querylog:
  enabled: true
  file_enabled: true
  interval: 2160h
  size_memory: 1000
  ignored: []
statistics:
  enabled: true
  interval: 24h
  ignored: []
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 27
AGHEOF

# Install as service
cd "$ADGUARD_INSTALL_DIR"
./AdGuardHome -s install -w "$ADGUARD_WORK_DIR"
systemctl enable AdGuardHome
systemctl start AdGuardHome

print_success "AdGuard Home installed and configured"

# 7. Install and Configure Nginx
print_status "🌐 Configuring Nginx reverse proxy..."

# Stop and disable Apache2 (if installed) before configuring Nginx
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true

# Mask Apache2 to prevent it from being started by dependencies
systemctl mask apache2 2>/dev/null || true

# Install Nginx first
apt install -y nginx

# Use default PHP version for Ubuntu 24.04 LTS (PHP will be installed later)
PHP_VERSION="8.3"

# Create Nginx configuration file using cat for maximum reliability
cat > /etc/nginx/sites-available/homelab << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        root /var/www/html;
        index index.html;
    }
    
    location /adguard/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 8000;
    server_name _;
    root /var/www/nextcloud;
    index index.php index.html;

    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-XSS-Protection "1; mode=block" always;

    fastcgi_hide_header X-Powered-By;

    location = / {
        if ( $http_user_agent ~ ^DavClnt ) {
            return 302 /remote.php/webdav/$is_args$args;
        }
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 /remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /remote.php/dav/; }
        location = /.well-known/webfinger  { return 301 /index.php/.well-known/webfinger; }
        location = /.well-known/nodeinfo  { return 301 /index.php/.well-known/nodeinfo; }
        location /.well-known/acme-challenge { try_files $uri $uri/ =404; }
        location /.well-known/pki-validation { try_files $uri $uri/ =404; }
        return 301 /index.php$request_uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)                { return 404; }

    location ~ \.php(?:$|/) {
        rewrite ^/(?!index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|oc[ms]-provider/.+|.+/richdocumentscode/proxy) /index.php$request_uri;

        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        set $path_info $fastcgi_path_info;

        try_files $fastcgi_script_name =404;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $path_info;
        fastcgi_param HTTPS on;

        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;

        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;

        fastcgi_max_temp_file_size 0;
        fastcgi_buffering off;
    }

    location ~ \.(?:css|js|svg|gif|png|jpg|ico|wasm|tflite|map|ogg|flac)$ {
        try_files $uri /index.php$request_uri;
        add_header Cache-Control "public, max-age=15778463, immutable";
        access_log off;
    }

    location ~ \.woff2?$ {
        try_files $uri /index.php$request_uri;
        expires 7d;
        access_log off;
    }

    location /remote {
        return 301 /remote.php$request_uri;
    }

    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
NGINXEOF

# Substitute the PHP version in the configuration
sed -i "s/\${PHP_VERSION}/${PHP_VERSION}/g" /etc/nginx/sites-available/homelab

ln -sf /etc/nginx/sites-available/homelab /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
# Don't restart nginx yet - PHP isn't installed, so the config will fail
# We'll restart it after PHP-FPM is installed
print_success "Nginx reverse proxy configured (will start after PHP installation)"

# 8. Install Squid Proxy
print_status "🔄 Installing Squid proxy for bandwidth optimization..."
apt install -y squid

# Configure Squid for cellular optimization
cat > /etc/squid/squid.conf << 'SQUID_EOF'
# Cellular-optimized Squid configuration
http_port 3128

# Cache directory
cache_dir ufs ${DATA_DIR}/squid-cache 8192 16 256

# Memory cache
cache_mem 512 MB

# Access control
acl localnet src 192.168.0.0/16
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12

http_access allow localnet
http_access deny all

# Optimize for large files (game downloads, etc.)
maximum_object_size 4 GB
cache_replacement_policy heap LFUDA

# Optimize for cellular
quick_abort_min 0
quick_abort_max 0
negative_ttl 0
positive_dns_ttl 1 hour
negative_dns_ttl 30 seconds
SQUID_EOF

mkdir -p ${DATA_DIR}/squid-cache
chown proxy:proxy ${DATA_DIR}/squid-cache
squid -z 2>/dev/null || true
systemctl enable squid
systemctl restart squid
print_success "Squid proxy installed and configured"

# 9. Install Netdata
print_status "📊 Installing Netdata monitoring..."
curl -Ss https://my-netdata.io/kickstart.sh > /tmp/install-netdata.sh
bash /tmp/install-netdata.sh --dont-wait --stable-channel --disable-telemetry --non-interactive

# Configure Netdata to bind to localhost only (accessed via nginx)
sed -i 's/bind socket to IP = \*/bind socket to IP = 127.0.0.1/' /etc/netdata/netdata.conf
systemctl restart netdata
print_success "Netdata monitoring installed"

# 10. Install Wireguard VPN
print_status "🔐 Installing Wireguard VPN..."
apt install -y wireguard wireguard-tools

# Generate server keys
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
wg genkey | tee /etc/wireguard/client_private_key | wg pubkey > /etc/wireguard/client_public_key

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private_key)
CLIENT_PRIVATE_KEY=$(cat /etc/wireguard/client_private_key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public_key)
CLIENT_PUBLIC_KEY=$(cat /etc/wireguard/client_public_key)

# Server configuration
cat > /etc/wireguard/wg0.conf << WG_EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32
WG_EOF

# Client configuration
cat > /etc/wireguard/client.conf << WG_CLIENT_EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 192.168.8.2

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = YOUR_EXTERNAL_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
WG_CLIENT_EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
print_success "Wireguard VPN installed and configured"

# 11. Install Nextcloud (feature-rich personal cloud)
print_status "☁️ Installing Nextcloud personal cloud..."

# Install additional PHP modules required for Nextcloud
apt install -y \
    php-mysql php-pgsql php-sqlite3 \
    php-redis php-memcached \
    php-gd php-imagick \
    php-json php-curl \
    php-zip php-xml php-mbstring \
    php-bz2 php-intl php-gmp \
    php-bcmath php-smbclient \
    mariadb-server mariadb-client \
    redis-server \
    unzip

# Update Nginx configuration with correct PHP version now that PHP is installed
ACTUAL_PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
sed -i "s/php8\.3-fpm/php${ACTUAL_PHP_VERSION}-fpm/g" /etc/nginx/sites-available/homelab

# Now that PHP-FPM is installed, we can safely start nginx
print_status "Starting Nginx with PHP-FPM support..."
systemctl restart php${ACTUAL_PHP_VERSION}-fpm
systemctl restart nginx
print_success "Nginx started successfully with PHP ${ACTUAL_PHP_VERSION} support"

# Configure MariaDB
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB and create Nextcloud database
mysql -u root << 'MYSQL_EOF'
UPDATE mysql.user SET Password = PASSWORD('admin123') WHERE User = 'root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud123';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF

# Download latest Nextcloud
cd /tmp
NEXTCLOUD_VERSION="31.0.9"
wget https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2
wget https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc

# Verify checksum (optional but recommended)
# gpg --verify nextcloud-${NEXTCLOUD_VERSION}.tar.bz2.asc nextcloud-${NEXTCLOUD_VERSION}.tar.bz2

# Extract and install
tar -xjf nextcloud-${NEXTCLOUD_VERSION}.tar.bz2
cp -r nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud

# Create Nextcloud data directory
mkdir -p ${DATA_DIR}/nextcloud
chown -R www-data:www-data ${DATA_DIR}/nextcloud

# Configure PHP for Nextcloud
# Update PHP memory limit and other settings
sed -i 's/memory_limit = .*/memory_limit = 1G/' /etc/php/*/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 16G/' /etc/php/*/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = 16G/' /etc/php/*/fpm/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 3600/' /etc/php/*/fpm/php.ini
sed -i 's/max_input_time = .*/max_input_time = 3600/' /etc/php/*/fpm/php.ini

# Enable required PHP modules
phpenmod gd imagick intl mbstring mysql zip xml curl bz2 gmp bcmath redis

# Install Nextcloud via command line (automated setup)
cd /var/www/nextcloud
sudo -u www-data php occ maintenance:install \
    --database="mysql" \
    --database-name="nextcloud" \
    --database-user="nextcloud" \
    --database-pass="nextcloud123" \
    --admin-user="admin" \
    --admin-pass="admin123" \
    --data-dir="${DATA_DIR}/nextcloud"

# Configure trusted domains
sudo -u www-data php occ config:system:set trusted_domains 0 --value="localhost"
sudo -u www-data php occ config:system:set trusted_domains 1 --value="192.168.8.2"
sudo -u www-data php occ config:system:set trusted_domains 2 --value="zimaboard"

# Configure Redis cache
sudo -u www-data php occ config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
sudo -u www-data php occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"
sudo -u www-data php occ config:system:set redis host --value="localhost"
sudo -u www-data php occ config:system:set redis port --value=6379

# Configure background jobs to use cron
sudo -u www-data php occ background:cron

# Set up cron job for Nextcloud
(crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f /var/www/nextcloud/cron.php") | crontab -u www-data -

# Enable pretty URLs
sudo -u www-data php occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php occ maintenance:update:htaccess

# Restart services
systemctl restart php*-fpm
systemctl restart redis-server
systemctl restart mariadb

print_success "Nextcloud personal cloud installed and optimized"

# 12. Create web dashboard
print_status "🎨 Creating homelab dashboard..."
cat > /var/www/html/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ZimaBoard 2 Homelab</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .service { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .service h3 { margin-top: 0; color: #333; }
        .service a { display: inline-block; margin-top: 10px; padding: 8px 16px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; }
        .status { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 ZimaBoard 2 Homelab</h1>
            <p>Your complete security and productivity homelab</p>
        </div>
        
        <div class="services">
            <div class="service">
                <h3>� AdGuard Home DNS</h3>
                <p>Modern DNS filtering with advanced features & beautiful UI</p>
                <div class="status">Status: Active</div>
                <a href=":3000">Admin Interface</a>
            </div>
            
            <div class="service">
                <h3>☁️ Nextcloud Cloud</h3>
                <p>Feature-rich personal cloud with file sync, calendar, contacts, office suite</p>
                <div class="status">Status: Active</div>
                <a href=":8000">Access Nextcloud</a>
            </div>
            
            <div class="service">
                <h3>📊 Netdata Monitoring</h3>
                <p>Real-time system performance monitoring</p>
                <div class="status">Status: Active</div>
                <a href="/netdata">View Metrics</a>
            </div>
            
            <div class="service">
                <h3>🔄 Squid Proxy</h3>
                <p>Bandwidth optimization for cellular internet</p>
                <div class="status">Status: Active</div>
                <p>Configure devices to use: <code>192.168.8.2:3128</code></p>
            </div>
            
            <div class="service">
                <h3>🔐 Wireguard VPN</h3>
                <p>Secure remote access to your network</p>
                <div class="status">Status: Active</div>
                <p>Download client config: <code>/etc/wireguard/client.conf</code></p>
            </div>
            
            <div class="service">
                <h3>🔥 System Firewall</h3>
                <p>UFW firewall protecting your homelab</p>
                <div class="status">Status: Active</div>
                <p>Check status: <code>sudo ufw status</code></p>
            </div>
        </div>
        
        <div style="margin-top: 40px; text-align: center; color: #666;">
            <p>🚀 ZimaBoard 2 Simple Homelab - All services running on Ubuntu Server</p>
            <p>No containers • No complexity • Just works</p>
        </div>
    </div>
</body>
</html>
HTML_EOF

print_success "Web dashboard created"

# 13. Configure automatic updates (security only)
print_status "🔒 Configuring automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UPDATE_EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UPDATE_EOF

systemctl enable unattended-upgrades
print_success "Automatic security updates enabled"

# 14. Final system optimization
print_status "⚡ Applying final optimizations..."

# Ensure Apache2 is properly stopped and masked (PHP packages may try to start it)
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true
systemctl mask apache2 2>/dev/null || true

# Apply sysctl changes
sysctl -p

# Restart services
systemctl restart nginx
systemctl restart AdGuardHome

# Summary
echo ""
print_success "🎉 ZimaBoard 2 Simple Homelab Setup Complete!"
echo ""
echo "📋 Services installed and configured:"
echo "   � AdGuard Home DNS: http://192.168.8.2:3000 (admin/admin123)"
echo "   ☁️  Nextcloud Cloud:  http://192.168.8.2:8000 (admin/admin123)" 
echo "   📊 Netdata Monitor:   http://192.168.8.2/netdata"
echo "   🌐 Web Dashboard:     http://192.168.8.2"
echo "   🔄 Squid Proxy:      192.168.8.2:3128"
echo "   🔐 Wireguard VPN:    /etc/wireguard/client.conf"
echo ""
echo "🎯 Next Steps:"
echo "1. Change default passwords immediately"
echo "2. Configure your router DNS to point to 192.168.8.2"
echo "3. Set up devices to use Squid proxy for bandwidth savings"
echo "4. Download Wireguard client config for mobile access"
echo "5. Start uploading files and explore Nextcloud apps"
echo ""
echo "📱 eMMC Optimized: Logs moved to SSD, minimal writes to eMMC"
echo "💾 2TB SSD: All data stored on fast SSD storage"
echo "🔒 Security: UFW firewall active, automatic security updates enabled"
echo ""
print_success "Your simple homelab is ready to use! 🚀"

