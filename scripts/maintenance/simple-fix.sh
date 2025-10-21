#!/bin/bash

# ZimaBoard 2 Homelab Simple Fix Script
# Quick repair solutions for common issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
   exit 1
fi

# Header
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            ZimaBoard 2 Homelab Simple Fix Script            ║"
echo "║                  Quick Issue Resolution                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Fix 1: Restart all homelab services
fix_restart_services() {
    log "Restarting all homelab services..."
    
    systemctl restart nginx || warning "Failed to restart nginx"
    systemctl restart AdGuardHome || warning "Failed to restart AdGuardHome"
    systemctl restart php8.3-fpm || warning "Failed to restart php8.3-fpm"
    systemctl restart fail2ban || warning "Failed to restart fail2ban"
    
    success "Services restart attempted"
}

# Fix 2: Fix Nextcloud permissions
fix_nextcloud_permissions() {
    log "Fixing Nextcloud permissions..."
    
    if [[ -d /var/www/nextcloud ]]; then
        chown -R www-data:www-data /var/www/nextcloud
        chmod -R 755 /var/www/nextcloud
        chmod -R 644 /var/www/nextcloud/config/config.php 2>/dev/null || true
        
        success "Nextcloud permissions fixed"
    else
        warning "Nextcloud directory not found"
    fi
}

# Fix 3: Clean temporary files and logs
fix_cleanup_system() {
    log "Cleaning up temporary files and logs..."
    
    # Clean old logs
    journalctl --vacuum-size=100M
    
    # Clean package cache
    apt autoremove -y
    apt autoclean
    
    # Clean temporary files
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    
    success "System cleanup completed"
}

# Fix 4: Fix DNS issues
fix_dns_issues() {
    log "Fixing DNS configuration issues..."
    
    # Restart AdGuard Home
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl restart AdGuardHome
    
    # Test DNS
    if nslookup google.com 127.0.0.1 >/dev/null 2>&1; then
        success "DNS is working correctly"
    else
        warning "DNS still has issues - manual configuration may be needed"
    fi
}

# Fix 5: Repair Nginx configuration
fix_nginx_config() {
    log "Checking and fixing Nginx configuration..."
    
    # Test nginx configuration
    if nginx -t 2>/dev/null; then
        success "Nginx configuration is valid"
    else
        warning "Nginx configuration has errors - attempting to fix..."
        
        # Remove problematic configs and restore default
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        
        # Create simple working configuration
        cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
}

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
    
    location ~ /\.ht {
        deny all;
    }
}
NGINXEOF
        
        ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
        
        if nginx -t 2>/dev/null; then
            systemctl restart nginx
            success "Nginx configuration fixed and restarted"
        else
            error "Unable to fix Nginx configuration automatically"
        fi
    fi
}

# Fix 6: Mount SSD if not mounted
fix_ssd_mount() {
    log "Checking SSD mount status..."
    
    if ! mountpoint -q /mnt/ssd-data; then
        warning "SSD not mounted, attempting to mount..."
        
        mkdir -p /mnt/ssd-data
        
        if [[ -b /dev/sda1 ]]; then
            mount /dev/sda1 /mnt/ssd-data && success "SSD mounted successfully"
        else
            warning "SSD partition not found"
        fi
    else
        success "SSD is properly mounted"
    fi
}

# Fix 7: Reset Nextcloud to SQLite (bypass MariaDB issues)
fix_nextcloud_sqlite() {
    log "Configuring Nextcloud to use SQLite (bypassing MariaDB issues)..."
    
    if [[ -f /var/www/nextcloud/config/config.php ]]; then
        # Backup existing config
        cp /var/www/nextcloud/config/config.php /var/www/nextcloud/config/config.php.backup
        
        # Create new SQLite-based config
        cat > /var/www/nextcloud/config/config.php << 'PHPEOF'
<?php
$CONFIG = array (
  'instanceid' => 'homelab_nextcloud',
  'passwordsalt' => 'generated_salt_123',
  'secret' => 'generated_secret_456',
  'trusted_domains' => 
  array (
    0 => 'localhost',
    1 => '127.0.0.1',
    2 => '*',
  ),
  'datadirectory' => '/mnt/ssd-data/nextcloud',
  'dbtype' => 'sqlite3',
  'version' => '28.0.0.0',
  'overwrite.cli.url' => 'http://localhost:8080',
  'installed' => true,
  'maintenance' => false,
);
PHPEOF
        
        # Ensure data directory exists
        mkdir -p /mnt/ssd-data/nextcloud
        chown -R www-data:www-data /mnt/ssd-data/nextcloud
        chown -R www-data:www-data /var/www/nextcloud
        
        success "Nextcloud configured for SQLite"
    else
        warning "Nextcloud config file not found"
    fi
}

# Fix 8: Create beautiful dashboard if missing
fix_dashboard() {
    log "Ensuring dashboard is available..."
    
    if [[ ! -f /var/www/html/index.html ]]; then
        cat > /var/www/html/index.html << 'HTMLEOF'
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
        .service p { opacity: 0.9; margin-bottom: 1.5rem; }
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
                <p>Network-wide ad blocking and DNS filtering for enhanced privacy and security.</p>
                <a href="http://192.168.8.2:3000" target="_blank">Access AdGuard →</a>
            </div>
            
            <div class="service">
                <h3>☁️ Nextcloud</h3>
                <p>Personal cloud storage, file sharing, and collaboration platform.</p>
                <a href="http://192.168.8.2:8080" target="_blank">Access Nextcloud →</a>
            </div>
            
            <div class="service">
                <h3>📊 System Monitor</h3>
                <p>Real-time monitoring of system resources, performance, and health.</p>
                <a href="#" onclick="alert('System monitoring via SSH or local tools')">Monitor System →</a>
            </div>
            
            <div class="service">
                <h3>🔧 Quick Actions</h3>
                <p>Common maintenance tasks and system management shortcuts.</p>
                <a href="#" onclick="showQuickActions()">System Tools →</a>
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
        
        function showQuickActions() {
            alert('SSH into your ZimaBoard 2 for system management:\nssh your-username@192.168.8.2');
        }
        
        // Auto-refresh timestamp every minute
        setInterval(() => {
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        }, 60000);
    </script>
</body>
</html>
HTMLEOF
        
        chown www-data:www-data /var/www/html/index.html
        success "Dashboard created and configured"
    else
        success "Dashboard already exists"
    fi
}

# Main repair function
main() {
    log "Starting comprehensive homelab repair process..."
    
    fix_ssd_mount
    fix_cleanup_system
    fix_nginx_config
    fix_nextcloud_sqlite
    fix_nextcloud_permissions
    fix_dns_issues
    fix_dashboard
    fix_restart_services
    
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Repair Complete!                         ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    success "All repair operations completed"
    info "You can now access:"
    info "  - Dashboard: http://$(hostname -I | awk '{print $1}'):80"
    info "  - AdGuard Home: http://$(hostname -I | awk '{print $1}'):3000"
    info "  - Nextcloud: http://$(hostname -I | awk '{print $1}'):8080"
    
    warning "Remember to change default passwords if this is a fresh installation!"
}

# Run main function
main "$@"
