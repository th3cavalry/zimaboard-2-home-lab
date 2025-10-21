#!/bin/bash
################################################################################
# ZimaBoard 2 Homelab - Simple Installation Script
# 
# This script deploys a complete security homelab on Ubuntu Server 24.04 LTS
# optimized for ZimaBoard 2 with eMMC + SSD storage
#
# Usage: sudo ./install.sh
# Or: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
################################################################################

# Simple error handling
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=================================="
echo "🏠 ZimaBoard 2 Homelab Installer"
echo "=================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}✓ Root check passed${NC}"

# Check Ubuntu
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    echo -e "${RED}Error: This script requires Ubuntu${NC}"
    exit 1
fi

echo -e "${BLUE}✓ Ubuntu detected${NC}"

# Get system info
SYSTEM_IP=$(hostname -I | awk '{print $1}' | head -1)
if [[ -z "$SYSTEM_IP" ]]; then
    SYSTEM_IP="localhost"
fi

echo -e "${BLUE}✓ System IP: $SYSTEM_IP${NC}"
echo ""

echo "This will install:"
echo "🛡️ AdGuard Home (DNS filtering)"
echo "☁️ Nextcloud (Personal cloud)"
echo "🌐 Web Dashboard"
echo ""

# Auto-proceed in non-interactive mode, otherwise ask
if [[ ! -t 0 ]] || [[ "${DEBIAN_FRONTEND:-}" == "noninteractive" ]]; then
    echo "Running in non-interactive mode - proceeding automatically..."
    sleep 2
else
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

echo ""
echo "🚀 Starting installation..."
echo ""

################################################################################
# Phase 1: System Setup
################################################################################

echo "📦 Phase 1: Installing packages..."

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Update system
echo "  → Updating package lists..."
apt update >/dev/null 2>&1

# Install packages one by one to identify issues
echo "  → Installing curl..."
apt install -y curl >/dev/null 2>&1

echo "  → Installing wget..."
apt install -y wget >/dev/null 2>&1

echo "  → Installing nginx..."
apt install -y nginx >/dev/null 2>&1

echo "  → Installing UFW firewall..."
apt install -y ufw >/dev/null 2>&1

echo "  → Installing PHP..."
apt install -y php8.3-fpm php8.3-sqlite3 >/dev/null 2>&1

echo -e "${GREEN}✅ Packages installed${NC}"
echo ""

################################################################################
# Phase 2: Firewall
################################################################################

echo "🔥 Phase 2: Configuring firewall..."

# Reset UFW
ufw --force reset >/dev/null 2>&1

# Configure UFW
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow ssh >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 3000/tcp >/dev/null 2>&1
ufw allow 8080/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

echo -e "${GREEN}✅ Firewall configured${NC}"
echo ""

################################################################################
# Phase 3: AdGuard Home
################################################################################

echo "🛡️ Phase 3: Installing AdGuard Home..."

# Download AdGuard installer
cd /tmp
echo "  → Downloading AdGuard Home..."
if curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh -o adguard-install.sh; then
    echo "  → Installing AdGuard Home..."
    chmod +x adguard-install.sh
    ./adguard-install.sh -v >/dev/null 2>&1 || echo "  ⚠️ AdGuard installation completed with warnings"
    echo -e "${GREEN}✅ AdGuard Home installed${NC}"
else
    echo -e "${YELLOW}⚠️ AdGuard Home download failed - skipping${NC}"
fi
echo ""

################################################################################
# Phase 4: Nextcloud
################################################################################

echo "☁️ Phase 4: Installing Nextcloud..."

# Download Nextcloud
cd /tmp
echo "  → Downloading Nextcloud..."
if wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2; then
    echo "  → Extracting Nextcloud..."
    tar -xjf latest.tar.bz2 >/dev/null 2>&1
    
    echo "  → Installing Nextcloud..."
    if [[ -d /var/www/nextcloud ]]; then
        rm -rf /var/www/nextcloud.old
        mv /var/www/nextcloud /var/www/nextcloud.old
    fi
    mv nextcloud /var/www/
    chown -R www-data:www-data /var/www/nextcloud
    chmod -R 755 /var/www/nextcloud
    
    echo -e "${GREEN}✅ Nextcloud installed${NC}"
else
    echo -e "${YELLOW}⚠️ Nextcloud download failed - skipping${NC}"
fi
echo ""

################################################################################
# Phase 5: Web Server
################################################################################

echo "🌐 Phase 5: Configuring web server..."

# Create dashboard
echo "  → Creating dashboard..."
cat > /var/www/html/index.html << 'DASHBOARD_END'
<!DOCTYPE html>
<html>
<head>
    <title>ZimaBoard 2 Homelab</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            text-align: center;
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 0.5em;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .service {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .service h3 {
            margin-top: 0;
            font-size: 1.3em;
        }
        .service a {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            color: white;
            text-decoration: none;
            padding: 10px 20px;
            border-radius: 25px;
            margin-top: 10px;
            transition: background 0.3s;
        }
        .service a:hover {
            background: rgba(255,255,255,0.3);
        }
        .status {
            margin-top: 30px;
            font-size: 0.9em;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏠 ZimaBoard 2 Homelab</h1>
        <p>Your Personal Security & Privacy Hub</p>
        
        <div class="services">
            <div class="service">
                <h3>🛡️ AdGuard Home</h3>
                <p>Network-wide ad blocking and DNS filtering</p>
                <a href="http://SYSTEM_IP:3000" target="_blank">Access AdGuard</a>
            </div>
            
            <div class="service">
                <h3>☁️ Nextcloud</h3>
                <p>Personal cloud storage and file sharing</p>
                <a href="http://SYSTEM_IP:8080" target="_blank">Access Nextcloud</a>
            </div>
        </div>
        
        <div class="status">
            <p>🟢 System Status: Online</p>
            <p>Last updated: <span id="time"></span></p>
        </div>
    </div>
    
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
DASHBOARD_END

# Replace IP placeholder
sed -i "s/SYSTEM_IP/$SYSTEM_IP/g" /var/www/html/index.html

# Configure Nextcloud site
echo "  → Configuring Nextcloud..."
cat > /etc/nginx/sites-available/nextcloud << 'NGINX_END'
server {
    listen 8080;
    server_name _;
    root /var/www/nextcloud;
    index index.php index.html;
    
    client_max_body_size 512M;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX_END

# Enable Nextcloud site
ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/ 2>/dev/null

# Start services
echo "  → Starting services..."
systemctl enable nginx >/dev/null 2>&1
systemctl start nginx >/dev/null 2>&1
systemctl enable php8.3-fpm >/dev/null 2>&1
systemctl start php8.3-fpm >/dev/null 2>&1

echo -e "${GREEN}✅ Web server configured${NC}"
echo ""

################################################################################
# Installation Complete
################################################################################

echo "=================================="
echo -e "${GREEN}�� Installation Complete!${NC}"
echo "=================================="
echo ""
echo "Your services are now available at:"
echo "🏠 Main Dashboard:  http://$SYSTEM_IP"
echo "🛡️ AdGuard Home:    http://$SYSTEM_IP:3000"
echo "☁️ Nextcloud:       http://$SYSTEM_IP:8080"
echo ""
echo "Next Steps:"
echo "1. Visit AdGuard Home to complete setup"
echo "2. Visit Nextcloud to create admin account"
echo "3. Configure your router to use $SYSTEM_IP as DNS"
echo ""
echo -e "${GREEN}✨ Happy homelabbing! 🚀${NC}"
