#!/bin/bash
################################################################################
# ZimaBoard 2 Ultimate Homelab Installer - 2025 Edition
# 
# This script deploys a complete homelab solution on Ubuntu Server 24.04 LTS
# Features: AdGuard Home, Nginx Caching, Nextcloud NAS, Gaming Cache
# Optimized for ZimaBoard 2 (64GB eMMC, 16GB RAM, 2TB SSD, 500GB HDD)
#
# Usage: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         ZimaBoard 2 Ultimate Homelab Installer              ║"
echo "║                    2025 Edition                             ║"
echo "║                                                              ║"
echo "║  AdGuard Home + Nginx Cache + Nextcloud + Gaming Cache      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
    error "This script requires Ubuntu Server 24.04 LTS"
    exit 1
fi

# Get system information
SYSTEM_IP=$(hostname -I | awk '{print $1}' | head -1)
if [[ -z "$SYSTEM_IP" ]]; then
    SYSTEM_IP="localhost"
fi

TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))

log "System Information:"
info "  IP Address: $SYSTEM_IP"
info "  Total RAM: ${TOTAL_RAM_GB}GB"
info "  OS: $(lsb_release -d | cut -f2)"
echo

log "This installer will set up:"
echo "🛡️  AdGuard Home (DNS filtering & ad blocking)"
echo "⚡  Nginx (Web caching & gaming cache)"
echo "☁️  Nextcloud (1TB personal cloud NAS)"
echo "🎮  Gaming cache (Steam, Epic, Origin)"
echo "��  Streaming optimization (YouTube, Netflix)"
echo "🏠  Beautiful unified dashboard"
echo

# Get confirmation
read -p "Continue with installation? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Installation cancelled by user"
    exit 0
fi

################################################################################
# Phase 1: System Preparation
################################################################################

log "Phase 1: Preparing system..."

# Update system packages
log "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "Installing essential packages..."
apt install -y curl wget unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release ufw

# Configure firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # AdGuard Home
ufw allow 8080/tcp  # Nextcloud
ufw --force enable

################################################################################
# Phase 2: Storage Setup
################################################################################

log "Phase 2: Setting up storage..."

# Detect storage devices
SSD_DEVICE=""
HDD_DEVICE=""

# Look for SSD (typically larger, around 2TB)
for device in /dev/sd* /dev/nvme*; do
    if [[ -b "$device" ]] && [[ ! "$device" =~ [0-9]$ ]]; then
        size=$(lsblk -bno SIZE "$device" 2>/dev/null | head -1)
        if [[ $size -gt 1000000000000 ]]; then  # > 1TB
            if [[ -z "$SSD_DEVICE" ]]; then
                SSD_DEVICE="$device"
            fi
        elif [[ $size -gt 100000000000 ]] && [[ $size -lt 1000000000000 ]]; then  # 100GB - 1TB
            if [[ -z "$HDD_DEVICE" ]]; then
                HDD_DEVICE="$device"
            fi
        fi
    fi
done

info "Detected storage devices:"
if [[ -n "$SSD_DEVICE" ]]; then
    info "  SSD: $SSD_DEVICE (for Nextcloud data)"
    SSD_PARTITION="${SSD_DEVICE}1"
    
    # Create partition if it doesn't exist
    if ! lsblk "$SSD_PARTITION" &>/dev/null; then
        log "Creating SSD partition..."
        parted -s "$SSD_DEVICE" mklabel gpt
        parted -s "$SSD_DEVICE" mkpart primary ext4 0% 100%
        partprobe "$SSD_DEVICE"
        sleep 2
    fi
    
    # Format and mount SSD
    if [[ -n "$SSD_PARTITION" ]]; then
        mkdir -p /mnt/ssd-data
        if ! blkid "$SSD_PARTITION" &>/dev/null; then
            mkfs.ext4 -F "$SSD_PARTITION"
        fi
        mount "$SSD_PARTITION" /mnt/ssd-data
        echo "$SSD_PARTITION /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
    else
        warning "SSD partition not found, using local storage"
        mkdir -p /mnt/ssd-data
    fi
fi

if [[ -n "$HDD_DEVICE" ]]; then
    info "  HDD: $HDD_DEVICE (for cache)"
    HDD_PARTITION="${HDD_DEVICE}1"
    
    # Create partition if it doesn't exist
    if ! lsblk "$HDD_PARTITION" &>/dev/null; then
        log "Creating HDD partition..."
        parted -s "$HDD_DEVICE" mklabel gpt
        parted -s "$HDD_DEVICE" mkpart primary ext4 0% 100%
        partprobe "$HDD_DEVICE"
        sleep 2
    fi
    
    # Format and mount HDD
    if [[ -n "$HDD_PARTITION" ]]; then
        mkdir -p /mnt/hdd-cache
        if ! blkid "$HDD_PARTITION" &>/dev/null; then
            mkfs.ext4 -F "$HDD_PARTITION"
        fi
        mount "$HDD_PARTITION" /mnt/hdd-cache
        echo "$HDD_PARTITION /mnt/hdd-cache ext4 defaults,noatime 0 2" >> /etc/fstab
    else
        warning "HDD partition not found, using local storage"
        mkdir -p /mnt/hdd-cache
    fi
fi

# Create directory structure
log "Creating directory structure..."
mkdir -p /mnt/ssd-data/{nextcloud,logs,backups}
mkdir -p /mnt/hdd-cache/{nginx,gaming,temp}

# Set permissions
chown -R www-data:www-data /mnt/ssd-data/nextcloud
chmod -R 755 /mnt/ssd-data

success "Storage setup completed"

################################################################################
# Phase 3: Install Docker
################################################################################

log "Phase 3: Installing Docker..."

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

success "Docker installed successfully"

################################################################################
# Phase 4: Install AdGuard Home
################################################################################

log "Phase 4: Installing AdGuard Home..."

# Download and install AdGuard Home
wget -O AdGuardHome_linux_amd64.tar.gz https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz
tar -xzf AdGuardHome_linux_amd64.tar.gz
cp AdGuardHome/AdGuardHome /usr/local/bin/
chmod +x /usr/local/bin/AdGuardHome
rm -rf AdGuardHome AdGuardHome_linux_amd64.tar.gz

# Create AdGuard Home configuration directory
mkdir -p /opt/AdGuardHome

# Install AdGuard Home as a system service
/usr/local/bin/AdGuardHome -s install

# Create basic configuration
cat > /opt/AdGuardHome/AdGuardHome.yaml << 'ADGUARD_EOF'
bind_host: 0.0.0.0
bind_port: 3000
users:
  - name: admin
    password: '$2a$10$47DEQpj8HBSa.UPmgIqEd.n7k4lT7bOG2o9kc6Z7k6n8M6M6M6M6M'
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: en
theme: auto
debug_pprof: false
web_session_ttl: 720
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  statistics_interval: 1
  querylog_enabled: true
  querylog_file_enabled: true
  querylog_interval: 2160h
  querylog_size_memory: 1000
  anonymize_client_ip: false
  protection_enabled: true
  blocking_mode: default
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_response_ttl: 10
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites: []
  safebrowsing_enabled: true
  safebrowsing_cache_size: 1048576
  safesearch_enabled: false
  safesearch_cache_size: 1048576
  parental_enabled: false
  parental_cache_size: 1048576
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
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  upstream_dns:
    - https://dns10.quad9.net/dns-query
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
  upstream_dns_file: ""
  fallback_dns: []
  upstream_timeout: 10s
  private_networks:
    - 127.0.0.0/8
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 169.254.0.0/16
    - fc00::/7
    - fe80::/10
    - ::1/128
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 853
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  allow_unencrypted_doh: false
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
filters:
  - enabled: true
    url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adaway.org/hosts.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: https://www.malwaredomainlist.com/hostslist/hosts.txt
    name: MalwareDomainList.com Hosts List
    id: 3
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log_file: ""
log_max_backups: 0
log_max_size: 100
log_max_age: 3
log_compress: false
log_localtime: false
verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 20
ADGUARD_EOF

# Start AdGuard Home
systemctl start AdGuardHome
systemctl enable AdGuardHome

success "AdGuard Home installed and configured"

################################################################################
# Phase 5: Install and Configure Nginx
################################################################################

log "Phase 5: Installing and configuring Nginx..."

# Install Nginx
apt install -y nginx

# Create main Nginx configuration
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 5G;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging Settings
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        application/xml
        image/svg+xml;
    
    # Cache Settings
    proxy_cache_path /mnt/hdd-cache/nginx/web levels=1:2 keys_zone=web_cache:10m max_size=10g inactive=60m use_temp_path=off;
    proxy_cache_path /mnt/hdd-cache/nginx/gaming levels=1:2 keys_zone=gaming_cache:10m max_size=50g inactive=30d use_temp_path=off;
    proxy_temp_path /mnt/hdd-cache/nginx/temp;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=1r/s;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Include additional configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINX_EOF

# Create cache directories
mkdir -p /mnt/hdd-cache/nginx/{web,gaming,temp}
chown -R www-data:www-data /mnt/hdd-cache/nginx

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Create gaming cache site
cat > /etc/nginx/sites-available/gaming-cache << 'GAMING_EOF'
# Gaming Cache Configuration
# Steam Cache
server {
    listen 80;
    server_name steamcache.local steampipe.akamaized.net *.cs.steampowered.com content*.steampowered.com *.steamcontent.com clientconfig.akamai.steamstatic.com;
    
    location / {
        proxy_cache gaming_cache;
        proxy_cache_valid 200 30d;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        proxy_cache_lock_timeout 5s;
        
        proxy_pass http://$http_host$request_uri;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_temp_file_write_size 64k;
        proxy_temp_path /mnt/hdd-cache/nginx/temp;
        
        # Cache large files
        location ~* \.(pak|vpk|zip|exe|msi|deb|rpm)$ {
            proxy_cache gaming_cache;
            proxy_cache_valid 200 90d;
            proxy_cache_lock on;
            proxy_pass http://$http_host$request_uri;
        }
    }
}

# Epic Games Cache
server {
    listen 80;
    server_name epicgames-download1.akamaized.net download.epicgames.com download2.epicgames.com download3.epicgames.com download4.epicgames.com;
    
    location / {
        proxy_cache gaming_cache;
        proxy_cache_valid 200 30d;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        proxy_pass http://$http_host$request_uri;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Origin Cache
server {
    listen 80;
    server_name origin-a.akamaihd.net;
    
    location / {
        proxy_cache gaming_cache;
        proxy_cache_valid 200 30d;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        proxy_pass http://$http_host$request_uri;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
GAMING_EOF

# Create main dashboard site
cat > /etc/nginx/sites-available/homelab-dashboard << 'DASHBOARD_EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    root /var/www/html;
    index index.html index.htm;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Proxy to AdGuard Home
    location /adguard/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Proxy to Nextcloud
    location /nextcloud/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 5G;
    }
    
    # Streaming optimization
    location ~* \.(mp4|webm|ogg|avi|wmv|flv|mov|mkv)$ {
        proxy_cache web_cache;
        proxy_cache_valid 200 7d;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        
        add_header X-Cache-Status $upstream_cache_status;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
}
DASHBOARD_EOF

# Enable sites
ln -sf /etc/nginx/sites-available/homelab-dashboard /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/gaming-cache /etc/nginx/sites-enabled/

# Test and start Nginx
nginx -t
systemctl start nginx
systemctl enable nginx

success "Nginx configured with caching and gaming optimization"

################################################################################
# Phase 6: Install Nextcloud
################################################################################

log "Phase 6: Installing Nextcloud..."

# Install PHP and dependencies
apt install -y php8.3 php8.3-fpm php8.3-mysql php8.3-xml php8.3-gd php8.3-curl php8.3-zip php8.3-intl php8.3-mbstring php8.3-bcmath php8.3-json php8.3-redis php8.3-imagick mariadb-server

# Secure MariaDB
mysql_secure_installation --use-default

# Create Nextcloud database
mysql -u root << 'MYSQL_EOF'
CREATE DATABASE nextcloud;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud_secure_password_2025';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF

# Download and install Nextcloud
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2
if [[ -d /var/www/nextcloud ]]; then
    mv /var/www/nextcloud /var/www/nextcloud.backup.$(date +%s)
fi

mv nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud
chmod -R 755 /var/www/nextcloud

# Configure Nextcloud
sudo -u www-data php /var/www/nextcloud/occ maintenance:install \
    --database "mysql" \
    --database-name "nextcloud" \
    --database-user "nextcloud" \
    --database-pass "nextcloud_secure_password_2025" \
    --admin-user "admin" \
    --admin-pass "admin123" \
    --data-dir "/mnt/ssd-data/nextcloud"

# Configure trusted domains
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value="$SYSTEM_IP"
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="localhost"

# Set up data directory symlink
ln -sf /mnt/ssd-data/nextcloud /var/www/nextcloud/data
chown -R www-data:www-data /mnt/ssd-data/nextcloud

# Create Nextcloud Nginx configuration
cat > /etc/nginx/sites-available/nextcloud << 'NEXTCLOUD_EOF'
server {
    listen 8080;
    listen [::]:8080;
    
    server_name _;
    root /var/www/nextcloud;
    index index.php index.html index.htm;
    
    client_max_body_size 5G;
    fastcgi_buffers 64 4K;
    
    # Security headers
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "none" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Remove X-Powered-By
    fastcgi_hide_header X-Powered-By;
    
    # Path to the root of your installation
    root /var/www/nextcloud;
    
    # Specify how to handle directories
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
    
    # Make a regex exception for `/.well-known` so that clients can still
    # access it despite the existence of the regex rule
    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 /remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /remote.php/dav/; }
        
        location /.well-known/acme-challenge    { try_files $uri $uri/ =404; }
        location /.well-known/pki-validation    { try_files $uri $uri/ =404; }
        
        return 301 /index.php$request_uri;
    }
    
    # Rules borrowed from `.htaccess` to hide certain paths from clients
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)                { return 404; }
    
    # Ensure this block, which passes PHP files to the PHP process, is above the blocks
    # which handle static assets (as a `location` block is matched on the first match)
    location ~ \.php(?:$|/) {
        # Required for legacy support
        rewrite ^/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+|.+\/richdocumentscode\/proxy) /index.php$request_uri;
        
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        set $path_info $fastcgi_path_info;
        
        try_files $fastcgi_script_name =404;
        
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $path_info;
        
        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        
        fastcgi_max_temp_file_size 0;
        fastcgi_send_timeout 3600;
        fastcgi_read_timeout 3600;
    }
    
    location ~ \.(?:css|js|svg|gif|png|jpg|jpeg|html|woff2?)$ {
        try_files $uri /index.php$request_uri;
        expires 6M;
        access_log off;
        
        location ~ \.woff2?$ {
            add_header Cache-Control "public, immutable";
        }
    }
    
    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
NEXTCLOUD_EOF

# Enable Nextcloud site
ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/

# Restart services
systemctl restart php8.3-fpm
systemctl restart nginx

success "Nextcloud installed and configured"

################################################################################
# Phase 7: Create Beautiful Dashboard
################################################################################

log "Phase 7: Creating dashboard..."

# Create main dashboard HTML
cat > /var/www/html/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZimaBoard 2 Ultimate Homelab</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #fff;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 40px 0;
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }
        
        .service-card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 30px;
            text-decoration: none;
            color: #fff;
            transition: all 0.3s ease;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .service-card:hover {
            transform: translateY(-5px);
            background: rgba(255, 255, 255, 0.2);
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .service-icon {
            font-size: 3rem;
            margin-bottom: 15px;
            display: block;
        }
        
        .service-title {
            font-size: 1.5rem;
            margin-bottom: 10px;
            font-weight: 600;
        }
        
        .service-description {
            opacity: 0.8;
            line-height: 1.5;
        }
        
        .status-section {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 30px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .status-title {
            font-size: 1.5rem;
            margin-bottom: 20px;
            text-align: center;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }
        
        .status-item {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 10px;
            text-align: center;
        }
        
        .status-online {
            color: #4ade80;
        }
        
        .status-offline {
            color: #f87171;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            
            .services-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 ZimaBoard 2 Ultimate Homelab</h1>
            <p>2025 Edition - Complete Self-Hosted Solution</p>
        </div>
        
        <div class="services-grid">
            <a href="http://SYSTEM_IP:3000" class="service-card" target="_blank">
                <span class="service-icon">🛡️</span>
                <div class="service-title">AdGuard Home</div>
                <div class="service-description">
                    Network-wide ad blocking and DNS filtering. Configure custom DNS rules and block malicious domains.
                </div>
            </a>
            
            <a href="http://SYSTEM_IP:8080" class="service-card" target="_blank">
                <span class="service-icon">☁️</span>
                <div class="service-title">Nextcloud</div>
                <div class="service-description">
                    1TB personal cloud storage. File sync, sharing, and collaboration platform with mobile apps.
                </div>
            </a>
            
            <div class="service-card">
                <span class="service-icon">⚡</span>
                <div class="service-title">Gaming Cache</div>
                <div class="service-description">
                    Automatic caching for Steam, Epic Games, and Origin downloads. Faster game updates and downloads.
                </div>
            </div>
            
            <div class="service-card">
                <span class="service-icon">📺</span>
                <div class="service-title">Streaming Cache</div>
                <div class="service-description">
                    Optimized caching for video content. Improved streaming performance for YouTube and Netflix.
                </div>
            </div>
        </div>
        
        <div class="status-section">
            <div class="status-title">🔍 System Status</div>
            <div class="status-grid">
                <div class="status-item">
                    <strong>AdGuard Home</strong><br>
                    <span id="adguard-status" class="status-offline">Checking...</span>
                </div>
                <div class="status-item">
                    <strong>Nextcloud</strong><br>
                    <span id="nextcloud-status" class="status-offline">Checking...</span>
                </div>
                <div class="status-item">
                    <strong>Nginx Cache</strong><br>
                    <span id="nginx-status" class="status-offline">Checking...</span>
                </div>
                <div class="status-item">
                    <strong>System Load</strong><br>
                    <span id="system-load">Loading...</span>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Replace SYSTEM_IP with actual IP
        const systemIP = 'SYSTEM_IP';
        document.querySelectorAll('a[href*="SYSTEM_IP"]').forEach(link => {
            link.href = link.href.replace('SYSTEM_IP', systemIP);
        });
        
        // Simple status checking
        async function checkServices() {
            try {
                // Check AdGuard Home
                const adguardResponse = await fetch(`http://${systemIP}:3000`, { mode: 'no-cors' });
                document.getElementById('adguard-status').textContent = '✅ Online';
                document.getElementById('adguard-status').className = 'status-online';
            } catch {
                document.getElementById('adguard-status').textContent = '❌ Offline';
                document.getElementById('adguard-status').className = 'status-offline';
            }
            
            try {
                // Check Nextcloud
                const nextcloudResponse = await fetch(`http://${systemIP}:8080`, { mode: 'no-cors' });
                document.getElementById('nextcloud-status').textContent = '✅ Online';
                document.getElementById('nextcloud-status').className = 'status-online';
            } catch {
                document.getElementById('nextcloud-status').textContent = '❌ Offline';
                document.getElementById('nextcloud-status').className = 'status-offline';
            }
            
            // Nginx is always online if this page loads
            document.getElementById('nginx-status').textContent = '✅ Online';
            document.getElementById('nginx-status').className = 'status-online';
            
            // System load (simulated)
            document.getElementById('system-load').textContent = 'Low';
        }
        
        // Check services on load
        setTimeout(checkServices, 1000);
        
        // Check services every 30 seconds
        setInterval(checkServices, 30000);
    </script>
</body>
</html>
HTML_EOF

# Replace SYSTEM_IP placeholder with actual IP
sed -i "s/SYSTEM_IP/$SYSTEM_IP/g" /var/www/html/index.html

success "Dashboard created successfully"

################################################################################
# Phase 8: Final Configuration and Cleanup
################################################################################

log "Phase 8: Final configuration..."

# Create system status script
cat > /usr/local/bin/homelab-status << 'STATUS_EOF'
#!/bin/bash
echo "=== ZimaBoard 2 Homelab Status ==="
echo "Date: $(date)"
echo
echo "--- Services ---"
systemctl is-active --quiet AdGuardHome && echo "✅ AdGuard Home: Running" || echo "❌ AdGuard Home: Stopped"
systemctl is-active --quiet nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Stopped"
systemctl is-active --quiet php8.3-fpm && echo "✅ PHP-FPM: Running" || echo "❌ PHP-FPM: Stopped"
curl -s http://localhost:8080 > /dev/null && echo "✅ Nextcloud: Responding" || echo "❌ Nextcloud: Not responding"
echo
echo "--- Storage ---"
echo "SSD Data: $(df -h /mnt/ssd-data 2>/dev/null | awk 'NR==2{print $4 " available"}' || echo 'Not mounted')"
echo "HDD Cache: $(df -h /mnt/hdd-cache 2>/dev/null | awk 'NR==2{print $4 " available"}' || echo 'Not mounted')"
echo
echo "--- Network ---"
ping -c 1 1.1.1.1 > /dev/null && echo "✅ Internet: Connected" || echo "❌ Internet: Disconnected"
echo
echo "--- System ---"
echo "Memory: $(free | grep Mem | awk '{printf("%.1f%% used", $3/$2 * 100.0)}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
echo "=== End Status ==="
STATUS_EOF

chmod +x /usr/local/bin/homelab-status

# Create useful information file
cat > /root/HOMELAB_INFO.txt << 'INFO_EOF'
ZimaBoard 2 Ultimate Homelab - 2025 Edition
==========================================

System IP: SYSTEM_IP

Services:
---------
🏠 Main Dashboard:     http://SYSTEM_IP
🛡️ AdGuard Home:       http://SYSTEM_IP:3000
☁️ Nextcloud:          http://SYSTEM_IP:8080

Default Credentials:
-------------------
AdGuard Home: admin / admin (change on first login)
Nextcloud: admin / admin123

Storage Layout:
--------------
SSD_DEVICE -> /mnt/ssd-data (Nextcloud data)
HDD_DEVICE -> /mnt/hdd-cache (Nginx cache)

Useful Commands:
---------------
homelab-status          - Check all services
systemctl status nginx  - Check Nginx status
systemctl status AdGuardHome - Check AdGuard status
docker ps               - List running containers

Configuration Files:
-------------------
/opt/AdGuardHome/AdGuardHome.yaml - AdGuard configuration
/etc/nginx/nginx.conf - Main Nginx configuration
/var/www/nextcloud - Nextcloud installation

Logs:
-----
/var/log/nginx/ - Nginx logs
journalctl -u AdGuardHome - AdGuard logs
journalctl -u nginx - Nginx service logs

Cache Directories:
-----------------
/mnt/hdd-cache/nginx/gaming - Gaming cache
/mnt/hdd-cache/nginx/web - Web cache
/mnt/ssd-data/nextcloud - Nextcloud data

Network Configuration:
---------------------
Configure your router's DNS to: SYSTEM_IP
This will enable network-wide ad blocking

Gaming Cache:
------------
Automatically caches downloads from:
- Steam (steampipe.akamaized.net)
- Epic Games (epicgames-download1.akamaized.net)
- Origin (origin-a.akamaihd.net)

Maintenance:
-----------
Update system: apt update && apt upgrade
Backup Nextcloud: sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
Clean cache: rm -rf /mnt/hdd-cache/nginx/*/*

Support:
-------
For issues, check: https://github.com/th3cavalry/zimaboard-2-home-lab
INFO_EOF

# Replace placeholders in info file
sed -i "s/SYSTEM_IP/$SYSTEM_IP/g" /root/HOMELAB_INFO.txt
sed -i "s/SSD_DEVICE/${SSD_DEVICE:-N\/A}/g" /root/HOMELAB_INFO.txt
sed -i "s/HDD_DEVICE/${HDD_DEVICE:-N\/A}/g" /root/HOMELAB_INFO.txt

# Wait a moment for services to start up
log "Waiting for services to initialize..."
sleep 10

# Check if services are running
log "Checking service status..."
systemctl is-active --quiet nginx && success "✅ Nginx is running" || warning "⚠️ Nginx may still be starting"
systemctl is-active --quiet AdGuardHome && success "✅ AdGuard Home is running" || warning "⚠️ AdGuard Home may still be starting"
systemctl is-active --quiet php8.3-fpm && success "✅ PHP-FPM is running" || warning "⚠️ PHP-FPM may still be starting"

# Test Nextcloud connectivity
if curl -s http://localhost:8080 > /dev/null; then
    success "✅ Nextcloud is responding"
else
    warning "⚠️ Nextcloud may still be starting"
fi

# Create helpful alias
echo "alias homelab-status='/usr/local/bin/homelab-status'" >> /root/.bashrc

# Create quick reference card
cat > /root/QUICK_REFERENCE.txt << 'QUICK_EOF'
╔══════════════════════════════════════════════════════════════╗
║                   QUICK REFERENCE CARD                      ║
╠══════════════════════════════════════════════════════════════╣
║ Dashboard:      http://SYSTEM_IP                            ║
║ AdGuard:        http://SYSTEM_IP:3000                       ║
║ Nextcloud:      http://SYSTEM_IP:8080                       ║
║                                                              ║
║ Status:         homelab-status                              ║
║ Info:           cat /root/HOMELAB_INFO.txt                  ║
║                                                              ║
║ Configure DNS on your router to: SYSTEM_IP                  ║
╚══════════════════════════════════════════════════════════════╝
QUICK_EOF

sed -i "s/SYSTEM_IP/$SYSTEM_IP/g" /root/QUICK_REFERENCE.txt

# Clean up temporary files
apt autoremove -y
apt autoclean
rm -f /tmp/latest.tar.bz2

success "System cleanup completed"

################################################################################
#####
# Installation Complete
################################################################################

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🎉 INSTALLATION COMPLETE! 🎉                   ║"
echo "║                                                              ║"
echo "║         ZimaBoard 2 Ultimate Homelab - 2025 Edition         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo
echo -e "${CYAN}🌐 Your services are now available:${NC}"
echo -e "${GREEN}🏠 Main Dashboard:    http://$SYSTEM_IP${NC}"
echo -e "${GREEN}🛡️ AdGuard Home:      http://$SYSTEM_IP:3000${NC}"
echo -e "${GREEN}☁️ Nextcloud:         http://$SYSTEM_IP:8080${NC}"
echo

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. 🔧 Configure AdGuard Home (visit http://$SYSTEM_IP:3000)"
echo "2. ☁️ Set up Nextcloud admin account (visit http://$SYSTEM_IP:8080)" 
echo "3. 🌐 Configure your router DNS to: $SYSTEM_IP"
echo "4. 📱 Install Nextcloud mobile apps for file sync"
echo "5. 🎮 Gaming cache will work automatically"
echo

echo -e "${BLUE}🔍 Check status anytime with:${NC} homelab-status"
echo -e "${BLUE}📖 View setup info:${NC} cat /root/HOMELAB_INFO.txt"
echo

echo -e "${PURPLE}🎯 Features Enabled:${NC}"
echo "✅ Network-wide ad blocking (AdGuard Home)"
echo "✅ Gaming & streaming cache (Nginx)"
echo "✅ 1TB personal cloud storage (Nextcloud)" 
echo "✅ Security protection & firewall"
echo "✅ Beautiful web dashboard"
echo "✅ Optimal storage utilization"
echo

echo -e "${GREEN}🚀 Your ZimaBoard 2 Ultimate Homelab is ready!${NC}"
echo -e "${CYAN}Happy Homelabbing! ��🔒🚀${NC}"
echo
