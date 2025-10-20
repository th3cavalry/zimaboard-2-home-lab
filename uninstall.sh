#!/bin/bash
################################################################################
# ZimaBoard 2 Homelab - Complete Uninstall Script
#
# This script completely removes all homelab services and configurations
# Use with caution - this will delete all data!
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         ZimaBoard 2 Homelab Uninstaller v2.0.0           ║"
    echo "║                 COMPLETE REMOVAL TOOL                      ║"
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

################################################################################
# Confirmation and Safety Checks
################################################################################

confirm_uninstall() {
    print_header
    
    print_warning "⚠️  WARNING: This will completely remove ALL homelab services and data!"
    echo ""
    print_info "Services that will be removed:"
    echo "  • AdGuard Home (DNS server)"
    echo "  • Nextcloud (personal cloud)"
    echo "  • WireGuard (VPN server)"
    echo "  • Squid (proxy server)"
    echo "  • Netdata (monitoring)"
    echo "  • Nginx (web server)"
    echo "  • MariaDB (database)"
    echo "  • Redis (cache)"
    echo ""
    print_info "Data that will be deleted:"
    echo "  • All configuration files"
    echo "  • All databases"
    echo "  • All user files in Nextcloud"
    echo "  • All VPN configurations"
    echo "  • All logs and backups"
    echo ""
    
    read -p "Are you absolutely sure you want to continue? (Type 'DELETE' to confirm): " confirm
    if [[ "$confirm" != "DELETE" ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    print_warning "Last chance! This action cannot be undone!"
    read -p "Type 'YES I AM SURE' to proceed: " final_confirm
    if [[ "$final_confirm" != "YES I AM SURE" ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    print_info "Proceeding with complete removal..."
    sleep 2
}

################################################################################
# Service Removal Functions
################################################################################

stop_all_services() {
    print_info "🛑 Stopping all homelab services..."
    
    local services=(
        "AdGuardHome"
        "nginx"
        "mariadb"
        "redis-server"
        "wg-quick@wg0"
        "squid"
        "netdata"
        "fail2ban"
        "php8.3-fpm"
        "php8.2-fpm"
        "php8.1-fpm"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_info "Stopping $service..."
            systemctl stop "$service" || true
        fi
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            print_info "Disabling $service..."
            systemctl disable "$service" || true
        fi
    done
    
    print_success "All services stopped and disabled"
}

remove_adguard_home() {
    print_info "🔥 Removing AdGuard Home..."
    
    # Stop and uninstall service
    if [[ -f /opt/AdGuardHome/AdGuardHome ]]; then
        /opt/AdGuardHome/AdGuardHome -s stop 2>/dev/null || true
        /opt/AdGuardHome/AdGuardHome -s uninstall 2>/dev/null || true
    fi
    
    # Remove files
    rm -rf /opt/AdGuardHome/
    rm -rf /mnt/ssd-data/adguardhome/ 2>/dev/null || true
    rm -rf /opt/homelab-data/adguardhome/ 2>/dev/null || true
    
    print_success "AdGuard Home removed"
}

remove_nextcloud() {
    print_info "☁️ Removing Nextcloud..."
    
    # Remove web directory
    rm -rf /var/www/nextcloud/
    
    # Remove data directories
    rm -rf /mnt/ssd-data/nextcloud/ 2>/dev/null || true
    rm -rf /opt/homelab-data/nextcloud/ 2>/dev/null || true
    
    # Remove database
    if systemctl is-active --quiet mariadb; then
        mysql -u root -e "DROP DATABASE IF EXISTS nextcloud;" 2>/dev/null || true
        mysql -u root -e "DROP USER IF EXISTS 'nextcloud'@'localhost';" 2>/dev/null || true
        mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    fi
    
    print_success "Nextcloud removed"
}

remove_wireguard() {
    print_info "🔐 Removing WireGuard VPN..."
    
    # Stop interface
    wg-quick down wg0 2>/dev/null || true
    
    # Remove configurations
    rm -rf /etc/wireguard/
    
    # Remove iptables rules
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true
    
    print_success "WireGuard removed"
}

remove_nginx() {
    print_info "🌐 Removing Nginx..."
    
    # Remove custom configuration
    rm -f /etc/nginx/sites-available/homelab
    rm -f /etc/nginx/sites-enabled/homelab
    
    # Remove web content
    rm -rf /var/www/html/index.html
    
    print_success "Nginx configuration removed"
}

remove_squid() {
    print_info "🔄 Removing Squid proxy..."
    
    # Remove cache directory
    rm -rf /mnt/ssd-data/squid-cache/ 2>/dev/null || true
    rm -rf /opt/homelab-data/squid-cache/ 2>/dev/null || true
    
    # Reset configuration to default
    if [[ -f /etc/squid/squid.conf.backup ]]; then
        mv /etc/squid/squid.conf.backup /etc/squid/squid.conf
    else
        apt-get install --reinstall -y squid 2>/dev/null || true
    fi
    
    print_success "Squid proxy removed"
}

remove_databases() {
    print_info "🗄️ Removing databases..."
    
    # Stop MariaDB
    systemctl stop mariadb 2>/dev/null || true
    
    # Remove database files
    rm -rf /var/lib/mysql/
    rm -rf /mnt/ssd-data/mysql/ 2>/dev/null || true
    
    # Remove Redis data
    rm -rf /var/lib/redis/
    
    print_success "Databases removed"
}

################################################################################
# Package Removal
################################################################################

remove_packages() {
    print_info "📦 Removing installed packages..."
    
    # Packages to remove
    local packages=(
        "adguard-home"
        "nginx"
        "mariadb-server"
        "mariadb-client"
        "redis-server"
        "wireguard"
        "wireguard-tools"
        "squid"
        "netdata"
        "php8.3*"
        "php8.2*"
        "php8.1*"
        "fail2ban"
    )
    
    print_info "Removing packages (this may take a few minutes)..."
    apt-get purge -y "${packages[@]}" 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true
    
    print_success "Packages removed"
}

################################################################################
# System Configuration Cleanup
################################################################################

cleanup_firewall() {
    print_info "🔥 Cleaning up firewall rules..."
    
    # Remove homelab-specific rules
    ufw delete allow 53/tcp 2>/dev/null || true
    ufw delete allow 53/udp 2>/dev/null || true
    ufw delete allow 3000/tcp 2>/dev/null || true
    ufw delete allow 8000/tcp 2>/dev/null || true
    ufw delete allow 3128/tcp 2>/dev/null || true
    ufw delete allow 19999/tcp 2>/dev/null || true
    ufw delete allow 51820/udp 2>/dev/null || true
    
    # Reset to default if desired
    read -p "Reset UFW to default settings? (y/N): " reset_ufw
    if [[ "$reset_ufw" == "y" ]]; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        print_info "UFW reset to default settings"
    fi
    
    print_success "Firewall cleanup complete"
}

restore_system_settings() {
    print_info "⚙️ Restoring system settings..."
    
    # Restore swap settings
    sysctl vm.swappiness=60
    sed -i '/vm.swappiness/d' /etc/sysctl.conf
    sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
    
    # Restore mount options (remove noatime)
    if [[ -f /etc/fstab.backup ]]; then
        mv /etc/fstab.backup /etc/fstab
        print_info "Restored original fstab"
    else
        sed -i 's/,noatime//g' /etc/fstab
    fi
    
    # Restore log directory if it was moved
    if [[ -L /var/log && -d /var/log.old ]]; then
        rm -f /var/log
        mv /var/log.old /var/log
        print_info "Restored log directory"
    fi
    
    # Remove IP forwarding
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sysctl net.ipv4.ip_forward=0
    
    print_success "System settings restored"
}

cleanup_storage() {
    print_info "💾 Cleaning up storage..."
    
    # Remove SSD mount points and fstab entries
    if mountpoint -q /mnt/ssd-data 2>/dev/null; then
        umount /mnt/ssd-data || true
    fi
    
    if mountpoint -q /mnt/ssd-backup 2>/dev/null; then
        umount /mnt/ssd-backup || true
    fi
    
    # Clean up fstab entries
    sed -i '/homelab-data/d' /etc/fstab 2>/dev/null || true
    sed -i '/homelab-backup/d' /etc/fstab 2>/dev/null || true
    sed -i '/ssd-data/d' /etc/fstab 2>/dev/null || true
    sed -i '/ssd-backup/d' /etc/fstab 2>/dev/null || true
    
    # Remove directories
    rm -rf /mnt/ssd-data/ /mnt/ssd-backup/
    rm -rf /opt/homelab-data/
    
    # Remove homelab scripts
    rm -rf /opt/homelab/
    
    print_success "Storage cleanup complete"
}

cleanup_cron_jobs() {
    print_info "⏰ Removing cron jobs..."
    
    # Remove www-data cron jobs (Nextcloud)
    crontab -u www-data -r 2>/dev/null || true
    
    # Remove root cron jobs related to homelab
    (crontab -l 2>/dev/null | grep -v "nextcloud\|backup\|homelab" | crontab -) || true
    
    print_success "Cron jobs cleaned up"
}

################################################################################
# Final Cleanup
################################################################################

final_cleanup() {
    print_info "🧹 Performing final cleanup..."
    
    # Remove any remaining configuration files
    rm -rf /etc/AdGuardHome/ 2>/dev/null || true
    
    # Clean package cache
    apt-get clean
    
    # Remove temporary files
    rm -rf /tmp/AdGuardHome* /tmp/nextcloud* /tmp/homelab*
    
    # Update package database
    apt-get update || true
    
    print_success "Final cleanup complete"
}

################################################################################
# Main Uninstall Process
################################################################################

main() {
    check_root
    confirm_uninstall
    
    print_info "🚀 Starting complete homelab removal..."
    echo ""
    
    # Stop all services first
    stop_all_services
    
    # Remove individual services
    remove_adguard_home
    remove_nextcloud  
    remove_wireguard
    remove_nginx
    remove_squid
    remove_databases
    
    # Remove packages
    remove_packages
    
    # System cleanup
    cleanup_firewall
    restore_system_settings
    cleanup_storage
    cleanup_cron_jobs
    
    # Final cleanup
    final_cleanup
    
    echo ""
    print_success "🎉 Complete homelab removal finished!"
    echo ""
    print_info "Summary of actions performed:"
    echo "  ✅ All services stopped and disabled"
    echo "  ✅ All configuration files removed"
    echo "  ✅ All data directories deleted"
    echo "  ✅ All packages uninstalled"
    echo "  ✅ Firewall rules cleaned up"
    echo "  ✅ System settings restored"
    echo "  ✅ Storage mounts removed"
    echo "  ✅ Cron jobs deleted"
    echo ""
    print_warning "⚠️  A system reboot is recommended to complete the cleanup process"
    echo ""
    
    read -p "Reboot now? (y/N): " reboot_now
    if [[ "$reboot_now" == "y" ]]; then
        print_info "Rebooting system..."
        reboot
    else
        print_info "Please reboot manually when convenient"
    fi
}

# Run main function
main "$@"
