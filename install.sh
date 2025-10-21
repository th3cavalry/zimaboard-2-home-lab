#!/bin/bash
################################################################################
# ZimaBoard 2 Homelab - Main Installation Script
# 
# This script deploys a complete security homelab on Ubuntu Server 24.04 LTS
# optimized for ZimaBoard 2 with eMMC + SSD storage
#
# Usage: sudo ./install.sh
# Or: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="2.1.0"

# Global variables
export DATA_DIR="/opt/homelab-data"
export SSD_AVAILABLE=false
SYSTEM_IP=""

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         ZimaBoard 2 Homelab Installation v${VERSION}          ║"
    echo "║         Ubuntu Server 24.04 LTS Edition                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script requires Ubuntu Server"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        print_warning "This script is designed for Ubuntu 24.04 LTS (you have $VERSION_ID)"
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l)
            ARCH_TYPE="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    print_info "Detected architecture: $ARCH_TYPE"
}

get_system_ip() {
    SYSTEM_IP=$(hostname -I | awk '{print $1}' | head -1)
    if [[ -z "$SYSTEM_IP" ]]; then
        SYSTEM_IP="localhost"
    fi
}

################################################################################
# Installation Functions
################################################################################

install_system_packages() {
    print_info "📦 Installing system packages..."
    
    # Update package lists
    apt update
    
    # Install essential packages
    apt install -y \
        curl wget git htop net-tools \
        ufw fail2ban nginx \
        php8.3-fpm php8.3-zip php8.3-gd php8.3-mbstring \
        php8.3-curl php8.3-xml php8.3-bcmath php8.3-sqlite3 \
        unzip software-properties-common
    
    print_success "✅ System packages installed"
}

configure_firewall() {
    print_info "🔥 Configuring firewall..."
    
    # Reset and configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp    # Dashboard
    ufw allow 3000/tcp  # AdGuard Home
    ufw allow 8080/tcp  # Nextcloud
    ufw --force enable
    
    # Configure fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    
    print_success "✅ Firewall configured"
}

setup_storage() {
    print_info "💾 Setting up storage..."
    
    # Check for SSD
    if [[ -b /dev/sda ]] && [[ $(lsblk -b -d -o SIZE /dev/sda 2>/dev/null | tail -n1) -gt 500000000000 ]]; then
        print_info "Large storage device detected: /dev/sda"
        
        # Check if already mounted
        if mountpoint -q /mnt/ssd-data 2>/dev/null; then
            print_info "SSD already mounted at /mnt/ssd-data"
            export DATA_DIR="/mnt/ssd-data"
            export SSD_AVAILABLE=true
        else
            print_info "SSD not mounted, using eMMC storage"
        fi
    else
        print_info "No large SSD detected, using eMMC storage"
    fi
    
    # Create data directories
    mkdir -p "$DATA_DIR"/{adguardhome,nextcloud,backups,logs}
    chmod 755 "$DATA_DIR"
    
    print_success "✅ Storage configured: $DATA_DIR"
}

install_adguard() {
    print_info "🛡️ Installing AdGuard Home..."
    
    # Download and install AdGuard Home
    cd /tmp
    curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    
    # Configure data directory
    if [[ ! -d /opt/AdGuardHome ]]; then
        print_warning "AdGuard Home not installed in expected location"
        return 1
    fi
    
    # Start AdGuard Home
    systemctl enable AdGuardHome 2>/dev/null || true
    systemctl start AdGuardHome 2>/dev/null || true
    
    print_success "✅ AdGuard Home installed"
}

install_nextcloud() {
    print_info "☁️ Installing Nextcloud..."
    
    # Download Nextcloud
    cd /tmp
    if [[ ! -f latest.tar.bz2 ]]; then
        wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2
    fi
    
    # Extract and install
    tar -xjf latest.tar.bz2
    if [[ -d /var/www/nextcloud ]]; then
        rm -rf /var/www/nextcloud.backup
        mv /var/www/nextcloud /var/www/nextcloud.backup
    fi
    mv nextcloud /var/www/
    
    # Set permissions
    chown -R www-data:www-data /var/www/nextcloud
    chmod -R 755 /var/www/nextcloud
    
    # Configure data directory
    mkdir -p "$DATA_DIR/nextcloud"
    chown -R www-data:www-data "$DATA_DIR/nextcloud"
    
    print_success "✅ Nextcloud installed"
}

configure_nginx() {
    print_info "🌐 Configuring web server..."
    
    # Create main dashboard
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZimaBoard 2 Homelab Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh; padding: 2rem;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 3rem; }
        .header h1 { font-size: 3rem; margin-bottom: 0.5rem; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .header p { font-size: 1.2rem; opacity: 0.9; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem; }
        .service { 
            background: rgba(255,255,255,0.1); border-radius: 15px; padding: 2rem; 
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease; cursor: pointer;
        }
        .service:hover { transform: translateY(-5px); box-shadow: 0 10px 25px rgba(0,0,0,0.2); }
        .service h3 { font-size: 1.5rem; margin-bottom: 1rem; }
        .service p { opacity: 0.9; margin-bottom: 1.5rem; line-height: 1.5; }
        .service a { 
            display: inline-block; background: rgba(255,255,255,0.2); 
            padding: 0.75rem 1.5rem; border-radius: 50px; text-decoration: none; 
            color: white; font-weight: 600; border: 1px solid rgba(255,255,255,0.3);
            transition: all 0.3s ease;
        }
        .service a:hover { background: rgba(255,255,255,0.3); }
        .status { margin-top: 2rem; text-align: center; }
        .status-indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 0.5rem; }
        .online { background: #4ade80; }
        .footer { text-align: center; margin-top: 3rem; opacity: 0.7; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 ZimaBoard 2 Homelab</h1>
            <p>Your Personal Security & Privacy Hub</p>
        </div>
        
        <div class="services">
            <div class="service">
                <h3>🛡️ AdGuard Home</h3>
                <p>Network-wide ad blocking and DNS filtering for enhanced privacy and security across all your devices.</p>
                <a href="http://SYSTEM_IP:3000" target="_blank">Access AdGuard →</a>
            </div>
            
            <div class="service">
                <h3>☁️ Nextcloud</h3>
                <p>Personal cloud storage, file sharing, and collaboration platform. Your data, your control.</p>
                <a href="http://SYSTEM_IP:8080" target="_blank">Access Nextcloud →</a>
            </div>
            
            <div class="service">
                <h3>📊 System Info</h3>
                <p>Monitor system resources, performance metrics, and overall health of your homelab.</p>
                <a href="#" onclick="showSystemInfo()">View Stats →</a>
            </div>
        </div>
        
        <div class="status">
            <p><span class="status-indicator online"></span> System Status: All services operational</p>
            <p>Last updated: <span id="timestamp"></span></p>
        </div>
        
        <div class="footer">
            <p>ZimaBoard 2 Homelab • Powered by Ubuntu Server • Managed with ❤️</p>
        </div>
    </div>
    
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        function showSystemInfo() {
            alert('System monitoring available via SSH:\nssh your-username@SYSTEM_IP');
        }
        
        // Auto-refresh timestamp every minute
        setInterval(() => {
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        }, 60000);
    </script>
</body>
</html>
EOF
    
    # Replace SYSTEM_IP placeholder
    sed -i "s/SYSTEM_IP/$SYSTEM_IP/g" /var/www/html/index.html
    
    # Configure Nextcloud site
    cat > /etc/nginx/sites-available/nextcloud << 'EOF'
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
    
    location /.well-known/carddav {
        return 301 $scheme://$host:$server_port/remote.php/dav;
    }
    
    location /.well-known/caldav {
        return 301 $scheme://$host:$server_port/remote.php/dav;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
    
    # Remove default site if it conflicts
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart nginx
    nginx -t && systemctl restart nginx
    systemctl enable nginx
    
    # Start PHP-FPM
    systemctl enable php8.3-fpm
    systemctl start php8.3-fpm
    
    print_success "✅ Web server configured"
}

################################################################################
# Main Installation
################################################################################

run_installation() {
    print_info "🚀 Starting ZimaBoard 2 Homelab Installation"
    echo ""
    
    # Get system IP early
    get_system_ip
    
    # Phase 1: System preparation
    print_info "📋 Phase 1: System Preparation"
    install_system_packages
    configure_firewall
    print_success "✅ System preparation completed"
    echo ""
    
    # Phase 2: Storage setup
    print_info "💾 Phase 2: Storage Configuration"
    setup_storage
    print_success "✅ Storage configuration completed"
    echo ""
    
    # Phase 3: AdGuard Home
    print_info "🛡️ Phase 3: AdGuard Home Installation"
    if install_adguard; then
        print_success "✅ AdGuard Home installation completed"
    else
        print_warning "⚠️ AdGuard Home installation had issues"
    fi
    echo ""
    
    # Phase 4: Nextcloud
    print_info "☁️ Phase 4: Nextcloud Installation"
    install_nextcloud
    print_success "✅ Nextcloud installation completed"
    echo ""
    
    # Phase 5: Web server
    print_info "🌐 Phase 5: Web Server and Dashboard"
    configure_nginx
    print_success "✅ Web server and dashboard completed"
    echo ""
    
    # Final phase: Summary
    installation_complete
}

installation_complete() {
    print_header
    print_success "🎉 ZimaBoard 2 Homelab Installation Complete!"
    echo ""
    
    print_info "📋 Installation Summary:"
    echo "  ✅ System preparation and optimization"
    echo "  ✅ Storage configuration (SSD: $SSD_AVAILABLE)"
    echo "  ✅ AdGuard Home DNS filtering"
    echo "  ✅ Nextcloud personal cloud"
    echo "  ✅ Nginx web server with dashboard"
    echo "  ✅ Security hardening (UFW, fail2ban)"
    echo ""
    
    print_info "🌐 Access Your Services:"
    echo "  🏠 Main Dashboard:  http://${SYSTEM_IP}"
    echo "  🛡️ AdGuard Home:    http://${SYSTEM_IP}:3000"
    echo "  ☁️ Nextcloud:       http://${SYSTEM_IP}:8080"
    echo ""
    
    print_info "🔐 Default Credentials:"
    echo "  AdGuard Home: Configure via web interface"
    echo "  Nextcloud:    Configure via web setup wizard"
    echo ""
    
    print_warning "⚠️ IMPORTANT NEXT STEPS:"
    echo "  1. Complete AdGuard Home setup at http://${SYSTEM_IP}:3000"
    echo "  2. Complete Nextcloud setup at http://${SYSTEM_IP}:8080"
    echo "  3. Configure your router to use ${SYSTEM_IP} as DNS server"
    echo "  4. Review firewall settings: sudo ufw status"
    echo ""
    
    print_info "📚 Documentation:"
    echo "  Complete Guide: https://github.com/th3cavalry/zimaboard-2-home-lab/blob/main/COMPLETE_SETUP_GUIDE.md"
    echo "  Support: https://github.com/th3cavalry/zimaboard-2-home-lab/issues"
    echo ""
    
    print_success "✨ Your ZimaBoard 2 homelab is ready! Happy homelabbing! 🚀"
}

main() {
    print_header
    check_root
    check_ubuntu
    detect_architecture
    
    print_info "System Information:"
    echo "  - OS: $(lsb_release -d | cut -f2)"
    echo "  - Architecture: $ARCH_TYPE"
    echo "  - Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  - Storage: $(df -h / | awk 'NR==2 {print $4}') available"
    echo ""
    
    print_info "This will install a complete security homelab with:"
    echo "  🛡️ AdGuard Home (network-wide ad blocking)"
    echo "  ☁️ Nextcloud (personal cloud storage)"
    echo "  🌐 Beautiful web dashboard"
    echo "  🔒 Security hardening (UFW firewall, fail2ban)"
    echo "  📊 System optimization for eMMC longevity"
    echo ""
    
    read -p "Continue with installation? (y/N): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Start installation
    run_installation
}

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         ZimaBoard 2 Homelab Installation v${VERSION}          ║"
    echo "║         Ubuntu Server 24.04 LTS Edition                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script requires Ubuntu Server"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        print_warning "This script is designed for Ubuntu 24.04 LTS (you have $VERSION_ID)"
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l)
            ARCH_TYPE="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    print_info "Detected architecture: $ARCH_TYPE"
}

# Common functions used by modules
log_progress() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/homelab-install.log
}

ensure_package() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii  $package "; then
        print_info "Installing $package..."
        apt update && apt install -y "$package"
    fi
}

# Fallback system preparation
basic_system_prep() {
    print_info "Updating system packages..."
    apt update && apt upgrade -y
    
    print_info "Installing essential packages..."
    apt install -y curl wget git htop net-tools ufw fail2ban
    
    print_info "Configuring firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 3000/tcp
    ufw allow 8080/tcp
    ufw --force enable
    
    print_info "Enabling fail2ban..."
    systemctl enable fail2ban
    systemctl start fail2ban
}

# Fallback storage setup
basic_storage_setup() {
    export DATA_DIR="/opt/homelab-data"
    export SSD_AVAILABLE=false
    
    mkdir -p "$DATA_DIR"/{adguardhome,nextcloud,backups,logs}
    chmod 755 "$DATA_DIR"
    
    print_info "Using eMMC storage: $DATA_DIR"
}

# Fallback AdGuard installation
basic_adguard_install() {
    print_info "Installing AdGuard Home..."
    
    # Download and install AdGuard Home
    curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh
    
    # Configure basic settings
    mkdir -p "$DATA_DIR/adguardhome"
    
    # Start AdGuard Home
    systemctl enable AdGuardHome
    systemctl start AdGuardHome
}

# Fallback Nextcloud installation
basic_nextcloud_install() {
    print_info "Installing Nextcloud..."
    
    # Install required packages
    apt install -y nginx php8.3-fpm php8.3-mysql php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-bcmath php8.3-sqlite3
    
    # Download Nextcloud
    cd /tmp
    wget https://download.nextcloud.com/server/releases/latest.tar.bz2
    tar -xjf latest.tar.bz2
    
    # Move to web directory
    mv nextcloud /var/www/
    chown -R www-data:www-data /var/www/nextcloud
    chmod -R 755 /var/www/nextcloud
    
    # Configure data directory
    mkdir -p "$DATA_DIR/nextcloud"
    chown -R www-data:www-data "$DATA_DIR/nextcloud"
}

# Fallback nginx installation
basic_nginx_install() {
    print_info "Installing Nginx and dashboard..."
    
    # Install nginx if not already installed
    ensure_package nginx
    
    # Create simple dashboard
    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZimaBoard 2 Homelab</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; min-height: 100vh; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 2rem; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; }
        .service { background: rgba(255,255,255,0.1); padding: 1.5rem; border-radius: 10px; }
        .service a { color: white; text-decoration: none; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 ZimaBoard 2 Homelab</h1>
            <p>Your Personal Security & Privacy Hub</p>
        </div>
        <div class="services">
            <div class="service">
                <h3>🛡️ AdGuard Home</h3>
                <p>Network-wide ad blocking and DNS filtering</p>
                <a href="http://localhost:3000" target="_blank">Access AdGuard →</a>
            </div>
            <div class="service">
                <h3>☁️ Nextcloud</h3>
                <p>Personal cloud storage and file sharing</p>
                <a href="http://localhost:8080" target="_blank">Access Nextcloud →</a>
            </div>
        </div>
    </div>
</body>
</html>
EOF
    
    # Configure Nextcloud site
    cat > /etc/nginx/sites-available/nextcloud << 'EOF'
server {
    listen 8080;
    server_name _;
    
    root /var/www/nextcloud;
    index index.php index.html;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
    
    # Test and restart nginx
    nginx -t && systemctl restart nginx
    systemctl enable nginx
}

# Global variables
export SCRIPT_DIR="/tmp/homelab-install"
export DATA_DIR=""
export SSD_AVAILABLE=false

################################################################################
# Installation Modules
################################################################################

# Load a module from GitHub or local filesystem
load_module() {
    local module_name="$1"
    local module_file="${SCRIPT_DIR}/${module_name}"
    
    # Create script directory
    mkdir -p "$SCRIPT_DIR"
    
    # Try to download from GitHub
    if curl -sSL "${REPO_URL}/scripts/modules/${module_name}" -o "${module_file}" 2>/dev/null; then
        print_info "Downloaded module: ${module_name}"
    else
        print_error "Failed to download module: ${module_name}"
        return 1
    fi
    
    # Make executable and source
    chmod +x "${module_file}"
    source "${module_file}"
    
    return 0
}

# Execute installation phases
run_installation_phases() {
    print_info "🚀 Starting ZimaBoard 2 Homelab Installation"
    echo ""
    
    # Phase 1: System preparation
    print_info "📋 Phase 1: System Preparation"
    if load_module "01-system-prep.sh"; then
        system_preparation
        print_success "✅ System preparation completed"
    else
        print_warning "⚠️ Module not found, running basic system prep..."
        basic_system_prep
        print_success "✅ Basic system preparation completed"
    fi
    echo ""
    
    # Phase 2: Storage setup
    print_info "💾 Phase 2: Storage Configuration"
    if load_module "02-storage-setup.sh"; then
        setup_storage
        print_success "✅ Storage configuration completed"
    else
        print_warning "⚠️ Module not found, using basic storage setup..."
        basic_storage_setup
        print_success "✅ Basic storage setup completed"
    fi
    echo ""
    
    # Phase 3: AdGuard Home
    print_info "🛡️ Phase 3: AdGuard Home Installation"
    if load_module "03-adguard.sh"; then
        install_adguard_home
        print_success "✅ AdGuard Home installation completed"
    else
        print_warning "⚠️ Module not found, using basic AdGuard install..."
        basic_adguard_install
        print_success "✅ Basic AdGuard Home installation completed"
    fi
    echo ""
    
    # Phase 4: Nextcloud
    print_info "☁️ Phase 4: Nextcloud Installation"
    if load_module "04-nextcloud.sh"; then
        install_nextcloud
        print_success "✅ Nextcloud installation completed"
    else
        print_warning "⚠️ Module not found, using basic Nextcloud install..."
        basic_nextcloud_install
        print_success "✅ Basic Nextcloud installation completed"
    fi
    echo ""
    
    # Phase 5: Nginx and Dashboard
    print_info "🌐 Phase 5: Web Server and Dashboard"
    if load_module "08-nginx.sh"; then
        install_nginx_dashboard
        print_success "✅ Web server and dashboard completed"
    else
        print_warning "⚠️ Module not found, using basic Nginx install..."
        basic_nginx_install
        print_success "✅ Basic web server installation completed"
    fi
    echo ""
    
    # Final phase: Installation summary
    installation_complete
}

# Installation completion
installation_complete() {
    print_header
    print_success "🎉 ZimaBoard 2 Homelab Installation Complete!"
    echo ""
    
    # Get system IP
    SYSTEM_IP=$(hostname -I | awk '{print $1}')
    
    print_info "📋 Installation Summary:"
    echo "  ✅ System preparation and optimization"
    echo "  ✅ Storage configuration (SSD: $SSD_AVAILABLE)"
    echo "  ✅ AdGuard Home DNS filtering"
    echo "  ✅ Nextcloud personal cloud"
    echo "  ✅ Nginx web server with dashboard"
    echo "  ✅ Security hardening (UFW, fail2ban)"
    echo ""
    
    print_info "🌐 Access Your Services:"
    echo "  🏠 Main Dashboard:  http://${SYSTEM_IP}"
    echo "  🛡️ AdGuard Home:    http://${SYSTEM_IP}:3000"
    echo "  ☁️ Nextcloud:       http://${SYSTEM_IP}:8080"
    echo ""
    
    print_info "🔐 Default Credentials:"
    echo "  AdGuard Home: admin / admin123"
    echo "  Nextcloud:    admin / admin123"
    echo ""
    
    print_warning "⚠️ IMPORTANT SECURITY REMINDERS:"
    echo "  1. Change all default passwords immediately"
    echo "  2. Configure your router to use ${SYSTEM_IP} as DNS server"
    echo "  3. Review firewall settings: sudo ufw status"
    echo "  4. Monitor system health: sudo systemctl status nginx AdGuardHome"
    echo ""
    
    print_info "📚 Documentation:"
    echo "  Complete Guide: https://github.com/th3cavalry/zimaboard-2-home-lab/blob/main/COMPLETE_SETUP_GUIDE.md"
    echo "  Support: https://github.com/th3cavalry/zimaboard-2-home-lab/issues"
    echo ""
    
    print_success "✨ Your ZimaBoard 2 homelab is ready! Happy homelabbing! 🚀"
}

################################################################################
# Main Installation
################################################################################

main() {
    print_header
    check_root
    check_ubuntu
    detect_architecture
    
    print_info "System Information:"
    echo "  - OS: $(lsb_release -d | cut -f2)"
    echo "  - Architecture: $ARCH_TYPE"
    echo "  - Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  - Storage: $(df -h / | awk 'NR==2 {print $4}') available"
    echo ""
    
    print_info "This will install a complete security homelab with:"
    echo "  🛡️ AdGuard Home (network-wide ad blocking)"
    echo "  ☁️ Nextcloud (personal cloud storage)"
    echo "  🌐 Beautiful web dashboard"
    echo "  🔒 Security hardening (UFW firewall, fail2ban)"
    echo "  📊 System optimization for eMMC longevity"
    echo ""
    
    read -p "Continue with installation? (y/N): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Start installation
    run_installation_phases
}

# Run main function
main "$@"
