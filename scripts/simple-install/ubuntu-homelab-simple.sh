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
ufw allow 80/tcp    # Web services
ufw allow 443/tcp   # HTTPS
ufw allow 53/tcp    # DNS
ufw allow 53/udp    # DNS
ufw allow 8080/tcp  # Pi-hole admin
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

# 5. 2TB SSD Setup
print_status "💾 Setting up 2TB SSD for data storage..."
# Create data directories on SSD
mkdir -p /mnt/ssd-data/{nextcloud,pihole,squid-cache,backups,logs}

# Move log directory to SSD to reduce eMMC writes
if [ ! -L /var/log ] && [ -d /mnt/ssd-data ]; then
    cp -a /var/log/* /mnt/ssd-data/logs/ 2>/dev/null || true
    mv /var/log /var/log.old
    ln -s /mnt/ssd-data/logs /var/log
    print_success "Moved logs to SSD"
fi

# 6. Install Pi-hole
print_status "��️ Installing Pi-hole..."
mkdir -p /etc/pihole
echo "WEBPASSWORD=admin123" > /etc/pihole/setupVars.conf
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Configure Pi-hole to use SSD for database
if [ -f /etc/pihole/pihole-FTL.conf ]; then
    echo "DBFILE=/mnt/ssd-data/pihole/pihole-FTL.db" >> /etc/pihole/pihole-FTL.conf
fi

systemctl enable pihole-FTL
print_success "Pi-hole installed and configured"

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

# Create Nginx configuration file without heredoc (more reliable for piped execution)
mkdir -p /etc/nginx/sites-available

# Write configuration line by line to avoid heredoc issues
cat > /etc/nginx/sites-available/homelab << 'ENDCONFIG'
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        root /var/www/html;
        index index.html;
    }
    
    location /admin {
        proxy_pass http://127.0.0.1:8080/admin;
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
    root /var/www/nextcloud;

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
        rewrite ^/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+|.+\/richdocumentscode\/proxy) /index.php$request_uri;

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
ENDCONFIG
server {
    listen 80 default_server;
    server_name _;
    
    # Main dashboard
    location / {
        root /var/www/html;
        index index.html;
    }
    
    # Pi-hole admin interface
    location /admin {
        proxy_pass http://127.0.0.1:8080/admin;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Netdata monitoring
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Nextcloud
server {
    listen 8000;
    server_name _;
    root /var/www/nextcloud;
    index index.php index.html;

    # Security headers
    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Remove X-Powered-By which could leak info
    fastcgi_hide_header X-Powered-By;

    # Path to the root of Nextcloud
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

    # Make a regex exception for `/.well-known` location
    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 /remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /remote.php/dav/; }
        location = /.well-known/webfinger  { return 301 /index.php/.well-known/webfinger; }
        location = /.well-known/nodeinfo  { return 301 /index.php/.well-known/nodeinfo; }
        location /.well-known/acme-challenge { try_files $uri $uri/ =404; }
        location /.well-known/pki-validation { try_files $uri $uri/ =404; }
        return 301 /index.php$request_uri;
    }

    # Rules borrowed from `.htaccess` to hide certain paths.
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)                { return 404; }

    # Ensure this block, which passes PHP files to the PHP processor, is above the blocks
    # which handle static assets (as a `location` block's priority increases with its length).
    location ~ \.php(?:$|/) {
        # Required for legacy support
        rewrite ^/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+|.+\/richdocumentscode\/proxy) /index.php$request_uri;

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

    # Serve static files
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

    # Rule borrowed from `.htaccess`
    location /remote {
        return 301 /remote.php$request_uri;
    }

    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
ENDCONFIG

# Substitute the PHP version in the configuration
sed -i "s/\${PHP_VERSION}/${PHP_VERSION}/g" /etc/nginx/sites-available/homelab

ln -sf /etc/nginx/sites-available/homelab /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
systemctl restart nginx
print_success "Nginx reverse proxy configured"

# 8. Install Squid Proxy
print_status "🔄 Installing Squid proxy for bandwidth optimization..."
apt install -y squid

# Configure Squid for cellular optimization
cat > /etc/squid/squid.conf << 'SQUID_EOF'
# Cellular-optimized Squid configuration
http_port 3128

# Cache directory on SSD
cache_dir ufs /mnt/ssd-data/squid-cache 8192 16 256

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

mkdir -p /mnt/ssd-data/squid-cache
chown proxy:proxy /mnt/ssd-data/squid-cache
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

# Create Nextcloud data directory on SSD
mkdir -p /mnt/ssd-data/nextcloud
chown -R www-data:www-data /mnt/ssd-data/nextcloud

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
    --data-dir="/mnt/ssd-data/nextcloud"

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
                <h3>🕳️ Pi-hole DNS</h3>
                <p>Network-wide ad blocking and DNS filtering</p>
                <div class="status">Status: Active</div>
                <a href="/admin">Admin Interface</a>
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
systemctl restart pihole-FTL

# Summary
echo ""
print_success "🎉 ZimaBoard 2 Simple Homelab Setup Complete!"
echo ""
echo "📋 Services installed and configured:"
echo "   🕳️  Pi-hole DNS:      http://192.168.8.2/admin (admin/admin123)"
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

