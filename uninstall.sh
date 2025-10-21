#!/bin/bash
################################################################################
# ZimaBoard 2 Ultimate Homelab Uninstaller
# 
# This script safely removes all homelab services and data
# Use with caution - this will permanently delete your configuration and data!
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
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ⚠️  HOMELAB UNINSTALLER  ⚠️                      ║"
echo "║                                                              ║"
echo "║  This will PERMANENTLY REMOVE all homelab services          ║"
echo "║  and data. This action CANNOT be undone!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

echo
warning "This will remove:"
echo "🗑️  AdGuard Home (all DNS settings and logs)"
echo "🗑️  Nextcloud (ALL your files and data)"
echo "🗑️  Nginx (web server and cache)"
echo "🗑️  All configurations and logs"
echo "🗑️  Mounted storage configurations"
echo

echo -e "${RED}⚠️  ALL YOUR NEXTCLOUD DATA WILL BE PERMANENTLY DELETED! ⚠️${NC}"
echo
read -p "Are you absolutely sure you want to continue? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Uninstallation cancelled"
    exit 0
fi

echo
read -p "Type 'DELETE EVERYTHING' to confirm: " confirm
if [[ "$confirm" != "DELETE EVERYTHING" ]]; then
    info "Uninstallation cancelled"
    exit 0
fi

################################################################################
# Uninstallation Process
################################################################################

log "Starting uninstallation process..."

# Stop all services
log "Stopping services..."
systemctl stop AdGuardHome 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl stop php8.3-fpm 2>/dev/null || true
systemctl stop fail2ban 2>/dev/null || true

success "Services stopped"

# Disable services
log "Disabling services..."
systemctl disable AdGuardHome 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
systemctl disable php8.3-fpm 2>/dev/null || true
systemctl disable fail2ban 2>/dev/null || true

success "Services disabled"

# Remove AdGuard Home
log "Removing AdGuard Home..."
if [[ -d /opt/AdGuardHome ]]; then
    # Uninstall AdGuard Home service
    /opt/AdGuardHome/AdGuardHome -s uninstall 2>/dev/null || true
    rm -rf /opt/AdGuardHome
    success "AdGuard Home removed"
else
    info "AdGuard Home not found"
fi

# Remove Nextcloud
log "Removing Nextcloud..."
if [[ -d /var/www/nextcloud ]]; then
    rm -rf /var/www/nextcloud
    success "Nextcloud removed"
else
    info "Nextcloud not found"
fi

# Remove web files
log "Removing web files..."
if [[ -f /var/www/html/index.html ]]; then
    rm -f /var/www/html/index.html
    # Restore default nginx page
    echo "<h1>Welcome to nginx!</h1>" > /var/www/html/index.html
    success "Web files removed"
fi

# Remove nginx configurations
log "Removing nginx configurations..."
rm -f /etc/nginx/sites-available/dashboard 2>/dev/null || true
rm -f /etc/nginx/sites-available/nextcloud 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/dashboard 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/nextcloud 2>/dev/null || true

# Restore default nginx configuration
if [[ -f /etc/nginx/nginx.conf.backup ]]; then
    mv /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
    success "Nginx configuration restored"
fi

# Remove custom scripts
log "Removing custom scripts..."
rm -f /usr/local/bin/homelab-status 2>/dev/null || true
success "Custom scripts removed"

# Unmount storage
log "Unmounting storage..."
umount /mnt/ssd-data 2>/dev/null || true
umount /mnt/hdd-cache 2>/dev/null || true

# Remove from fstab
if [[ -f /etc/fstab ]]; then
    grep -v "/mnt/ssd-data" /etc/fstab > /tmp/fstab.tmp && mv /tmp/fstab.tmp /etc/fstab
    grep -v "/mnt/hdd-cache" /etc/fstab > /tmp/fstab.tmp && mv /tmp/fstab.tmp /etc/fstab
fi

success "Storage unmounted"

# Remove data directories
log "Removing data directories..."
echo
warning "⚠️  About to delete ALL data directories!"
echo "This includes:"
echo "  - /mnt/ssd-data (Nextcloud files)"
echo "  - /mnt/hdd-cache (Cache data)"
echo "  - /root/HOMELAB_INFO.txt"
echo

read -p "Proceed with data deletion? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf /mnt/ssd-data 2>/dev/null || true
    rm -rf /mnt/hdd-cache 2>/dev/null || true
    rm -f /root/HOMELAB_INFO.txt 2>/dev/null || true
    success "Data directories removed"
else
    info "Data directories preserved"
fi

# Remove packages (optional)
log "Package removal..."
echo
read -p "Remove installed packages (nginx, php, etc.)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt remove -y nginx php8.3-fpm php8.3-common php8.3-mysql php8.3-xml \
        php8.3-curl php8.3-zip php8.3-intl php8.3-mbstring php8.3-gd \
        php8.3-bcmath php8.3-sqlite3 fail2ban 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
    success "Packages removed"
else
    info "Packages preserved"
fi

# Reset firewall
log "Resetting firewall..."
echo
read -p "Reset firewall to default settings? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ufw --force reset
    ufw --force disable
    success "Firewall reset"
else
    info "Firewall unchanged"
fi

# Remove aliases
log "Cleaning up aliases..."
if [[ -f /root/.bashrc ]]; then
    grep -v "homelab-status" /root/.bashrc > /tmp/bashrc.tmp && mv /tmp/bashrc.tmp /root/.bashrc
    success "Aliases removed"
fi

################################################################################
# Uninstallation Complete
################################################################################

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║             ✅ UNINSTALLATION COMPLETE ✅                   ║"
echo "║                                                              ║"
echo "║        ZimaBoard 2 Ultimate Homelab has been removed        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo
echo -e "${CYAN}🧹 Cleanup Summary:${NC}"
echo "✅ All homelab services stopped and disabled"
echo "✅ AdGuard Home completely removed"
echo "✅ Nextcloud and all data removed"
echo "✅ Nginx configurations reset"
echo "✅ Custom scripts and aliases removed"
echo "✅ Storage unmounted and fstab cleaned"
echo

echo -e "${YELLOW}📋 What's left:${NC}"
echo "• Base Ubuntu Server 24.04 LTS installation"
echo "• Original system packages (unless removed)"
echo "• Storage drives (unmounted but not formatted)"
echo "• Network interface configuration"
echo

echo -e "${BLUE}🔄 To reinstall:${NC}"
echo "1. Re-download the installer"
echo "2. Run: sudo ./install.sh"
echo "3. Reconfigure your services"
echo

echo -e "${PURPLE}💾 Storage drives:${NC}"
echo "Your SSD and HDD are unmounted but not formatted."
echo "They can be safely remounted or reformatted as needed."
echo

echo -e "${GREEN}🎯 Uninstallation completed successfully!${NC}"
echo -e "${CYAN}Your ZimaBoard 2 is now clean and ready for fresh setup.${NC}"
echo