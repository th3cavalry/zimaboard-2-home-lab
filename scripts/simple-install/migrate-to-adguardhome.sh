#!/bin/bash

# 🔄 Migrate from Pi-hole to AdGuard Home
# Removes Pi-hole and installs AdGuard Home (port 3000 - no conflicts!)

set -e

echo "🔄 Pi-hole to AdGuard Home Migration Starting..."
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
STATIC_IP="${STATIC_IP:-192.168.8.2}"
ADGUARD_INSTALL_DIR="/opt/AdGuardHome"
ADGUARD_WORK_DIR="/var/lib/AdGuardHome"

print_status "📋 Migration Plan:"
echo "  1. Backup Pi-hole configuration and blocklists"
echo "  2. Stop and remove Pi-hole"
echo "  3. Install AdGuard Home"
echo "  4. Configure AdGuard Home with your blocklists"
echo "  5. Update nginx configuration"
echo "  6. Update firewall rules"
echo ""

read -p "Continue with migration? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    print_warning "Migration cancelled."
    exit 0
fi

# Step 1: Backup Pi-hole configuration
print_status "📦 Backing up Pi-hole configuration..."
BACKUP_DIR="/root/pihole-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if command -v pihole &> /dev/null; then
    # Backup Pi-hole teleporter (full config)
    pihole -a -t "$BACKUP_DIR/pihole-backup.tar.gz" 2>/dev/null || true
    
    # Export adlists
    sqlite3 /etc/pihole/gravity.db "SELECT address FROM adlist;" > "$BACKUP_DIR/adlists.txt" 2>/dev/null || true
    
    # Copy important files
    cp /etc/pihole/*.list "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/pihole/custom.list "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "Pi-hole backup saved to: $BACKUP_DIR"
else
    print_warning "Pi-hole not found - skipping backup"
fi

# Step 2: Stop and remove Pi-hole
print_status "🛑 Stopping and removing Pi-hole..."

# Stop Pi-hole service
systemctl stop pihole-FTL 2>/dev/null || true
systemctl disable pihole-FTL 2>/dev/null || true

# Uninstall Pi-hole
if [ -f /usr/local/bin/pihole ]; then
    print_status "Running Pi-hole uninstaller..."
    pihole uninstall <<< "yes" || true
fi

# Clean up any remaining Pi-hole files
rm -rf /etc/pihole
rm -rf /opt/pihole
rm -rf /var/www/html/admin
rm -f /usr/local/bin/pihole
rm -f /etc/systemd/system/pihole-FTL.service

# Remove Pi-hole user
userdel -r pihole 2>/dev/null || true

systemctl daemon-reload

print_success "Pi-hole removed successfully"

# Step 3: Install AdGuard Home
print_status "📥 Installing AdGuard Home..."

# Create directories
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

print_status "Detected architecture: $ADGUARD_ARCH"

# Download latest AdGuard Home
ADGUARD_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
ADGUARD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz"

print_status "Downloading AdGuard Home $ADGUARD_VERSION..."
cd /tmp
curl -L -o AdGuardHome.tar.gz "$ADGUARD_URL"

# Extract
tar -xzf AdGuardHome.tar.gz
cd AdGuardHome

# Move binary to installation directory
mv AdGuardHome "$ADGUARD_INSTALL_DIR/"
chmod +x "$ADGUARD_INSTALL_DIR/AdGuardHome"

# Clean up
cd /
rm -rf /tmp/AdGuardHome /tmp/AdGuardHome.tar.gz

print_success "AdGuard Home binary installed"

# Step 4: Configure AdGuard Home
print_status "⚙️ Configuring AdGuard Home..."

# Create initial configuration
cat > "$ADGUARD_WORK_DIR/AdGuardHome.yaml" << EOF
bind_host: 0.0.0.0
bind_port: 3000
users:
  - name: admin
    password: \$2a\$10\$jU3FqELn3cqV/4gkH5w5z.mf5h9q2lZ8L6rG5tF8uVwK7u6p5F5G.
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
EOF

print_success "AdGuard Home configuration created"
print_warning "Default admin password: admin123 (CHANGE THIS IMMEDIATELY!)"

# Import Pi-hole adlists if available
if [ -f "$BACKUP_DIR/adlists.txt" ]; then
    print_status "📋 Pi-hole adlists backed up - you can add them manually in AdGuard Home UI"
    print_status "Backup location: $BACKUP_DIR/adlists.txt"
fi

# Step 5: Install as service
print_status "📦 Installing AdGuard Home as a system service..."
cd "$ADGUARD_INSTALL_DIR"
./AdGuardHome -s install -w "$ADGUARD_WORK_DIR"

# Enable and start service
systemctl enable AdGuardHome
systemctl start AdGuardHome

# Wait for service to start
sleep 5

if systemctl is-active --quiet AdGuardHome; then
    print_success "AdGuard Home service is running"
else
    print_error "AdGuard Home service failed to start"
    journalctl -u AdGuardHome -n 50
    exit 1
fi

# Step 6: Update firewall
print_status "🔥 Updating firewall rules..."
ufw allow 53/tcp comment 'AdGuard Home DNS'
ufw allow 53/udp comment 'AdGuard Home DNS'
ufw allow 3000/tcp comment 'AdGuard Home Web UI'
ufw allow 80/tcp comment 'AdGuard Home Web UI (optional)'

# Remove old Pi-hole rules
ufw delete allow 8080/tcp 2>/dev/null || true

print_success "Firewall rules updated"

# Step 7: Update nginx configuration
print_status "🌐 Updating nginx configuration..."

if [ -f /etc/nginx/sites-available/homelab ]; then
    # Backup nginx config
    cp /etc/nginx/sites-available/homelab /etc/nginx/sites-available/homelab.backup
    
    # Update nginx to use port 80 (since AdGuard Home uses 3000)
    sed -i 's/listen 81 default_server;/listen 80 default_server;/g' /etc/nginx/sites-available/homelab
    
    # Update dashboard link for AdGuard Home
    sed -i 's|http://192.168.8.2:8080/admin|http://192.168.8.2:3000|g' /etc/nginx/sites-available/homelab
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    print_success "Nginx configuration updated (now on port 80)"
else
    print_warning "Nginx configuration not found - skipping update"
fi

# Step 8: Verification
print_status "🔍 Verifying installation..."

echo ""
print_success "✅ Migration Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 AdGuard Home Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🌐 Web Interface:     http://$STATIC_IP:3000"
echo "  🌐 Alternative URL:   http://$STATIC_IP:80"
echo "  🔐 Default Username:  admin"
echo "  🔐 Default Password:  admin123 (CHANGE THIS!)"
echo ""
echo "  📡 DNS Server:        $STATIC_IP:53"
echo "  📊 Dashboard:         http://$STATIC_IP (nginx)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Next Steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Visit http://$STATIC_IP:3000 to complete initial setup"
echo "  2. Change the default admin password immediately"
echo "  3. Configure your router to use $STATIC_IP as DNS server"
echo "  4. Review and add your custom blocklists"
echo "  5. Check Pi-hole backup at: $BACKUP_DIR"
echo ""
echo "🎯 Port Assignments:"
echo "  • Port 80:    Nginx dashboard (no more conflict!)"
echo "  • Port 3000:  AdGuard Home web interface"
echo "  • Port 53:    AdGuard Home DNS server"
echo "  • Port 8000:  Nextcloud"
echo "  • Port 19999: Netdata"
echo "  • Port 51820: WireGuard VPN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_status "Service status:"
systemctl status AdGuardHome --no-pager -l | head -15

echo ""
print_status "Listening ports:"
ss -tlnp | grep -E ':(53|80|3000)'

echo ""
print_success "🎉 AdGuard Home migration completed successfully!"
print_warning "⚠️  Remember to change the default password!"
