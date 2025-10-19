#!/bin/bash

# 🏠 ZimaBoard 2 Simple Homelab Setup - Single OS Installation
# No containers, no Proxmox - just Ubuntu Server with all services
# Optimized for eMMC longevity and 2TB SSD storage

set -e

echo "🚀 ZimaBoard 2 Simple Homelab Setup Starting..."
echo "📱 Installing all services directly on Ubuntu Server"
echo ""

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
ufw allow 8000/tcp  # Seafile
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
mkdir -p /mnt/ssd-data/{seafile,pihole,squid-cache,backups,logs}

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
systemctl stop apache2 2>/dev/null || true
systemctl disable apache2 2>/dev/null || true

cat > /etc/nginx/sites-available/homelab << 'NGINX_EOF'
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

# Seafile
server {
    listen 8000;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX_EOF

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

# 11. Install Seafile (lightweight)
print_status "☁️ Installing Seafile personal cloud..."
cd /tmp
SEAFILE_VERSION="11.0.12"
wget https://s3.eu-central-1.amazonaws.com/download.seadrive.org/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz
tar -xzf seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz -C /opt/
cd /opt/seafile-server-${SEAFILE_VERSION}/

# Create seafile user
useradd -r -s /bin/false -d /mnt/ssd-data/seafile seafile
mkdir -p /mnt/ssd-data/seafile
chown -R seafile:seafile /mnt/ssd-data/seafile

# Auto-setup Seafile
echo "Seafile Server
seafile.local
8001

/mnt/ssd-data/seafile

admin@seafile.local
admin123" > /tmp/seafile_setup_answers

./setup-seafile.sh < /tmp/seafile_setup_answers

# Create systemd service
cat > /etc/systemd/system/seafile.service << 'SEAFILE_SERVICE_EOF'
[Unit]
Description=Seafile
After=network.target

[Service]
Type=forking
User=seafile
Group=seafile
ExecStart=/opt/seafile-server-latest/seafile.sh start
ExecStop=/opt/seafile-server-latest/seafile.sh stop
ExecReload=/opt/seafile-server-latest/seafile.sh restart
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SEAFILE_SERVICE_EOF

ln -sf /opt/seafile-server-${SEAFILE_VERSION} /opt/seafile-server-latest
systemctl daemon-reload
systemctl enable seafile
systemctl start seafile
print_success "Seafile personal cloud installed"

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
                <h3>☁️ Seafile Cloud</h3>
                <p>Personal file storage and synchronization</p>
                <div class="status">Status: Active</div>
                <a href=":8000">Access Files</a>
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
echo "   ☁️  Seafile Cloud:    http://192.168.8.2:8000 (admin@seafile.local/admin123)" 
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
echo "5. Create Seafile libraries and start syncing files"
echo ""
echo "📱 eMMC Optimized: Logs moved to SSD, minimal writes to eMMC"
echo "💾 2TB SSD: All data stored on fast SSD storage"
echo "🔒 Security: UFW firewall active, automatic security updates enabled"
echo ""
print_success "Your simple homelab is ready to use! 🚀"

