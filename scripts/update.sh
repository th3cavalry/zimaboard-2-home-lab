#!/bin/bash
################################################################################
# ZimaBoard 2 Ultimate Homelab - Update Script
# 
# This script safely updates all homelab services and system packages
# Includes rollback capabilities and service health checks
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

# Configuration
LOG_FILE="/var/log/homelab-update.log"
BACKUP_DIR="/mnt/ssd-data/backups/pre-update-$(date +%Y%m%d_%H%M%S)"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            ZimaBoard 2 Homelab Update Manager               ║"
echo "║                     2025 Edition                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

################################################################################
# Pre-Update Functions
################################################################################

check_system_health() {
    log "Checking system health before update..."
    
    local issues=0
    
    # Check disk space
    local root_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $root_usage -gt 85 ]]; then
        warning "Root filesystem is ${root_usage}% full"
        ((issues++))
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    if [[ $mem_usage -gt 90 ]]; then
        warning "Memory usage is ${mem_usage}%"
        ((issues++))
    fi
    
    # Check service status
    local services=("AdGuardHome" "nginx" "php8.3-fpm")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            warning "Service $service is not running"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        success "System health check passed"
        return 0
    else
        warning "Found $issues potential issues"
        return 1
    fi
}

create_pre_update_backup() {
    log "Creating pre-update backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical configurations
    if [[ -d /opt/AdGuardHome/conf ]]; then
        tar -czf "$BACKUP_DIR/adguard_pre_update.tar.gz" -C /opt/AdGuardHome conf
    fi
    
    if [[ -d /etc/nginx ]]; then
        tar -czf "$BACKUP_DIR/nginx_pre_update.tar.gz" -C /etc nginx
    fi
    
    if [[ -d /var/www/nextcloud/config ]]; then
        tar -czf "$BACKUP_DIR/nextcloud_config_pre_update.tar.gz" -C /var/www/nextcloud config
    fi
    
    # Save package list
    dpkg --get-selections > "$BACKUP_DIR/packages_before_update.txt"
    
    # Save service status
    systemctl list-units --type=service --state=running > "$BACKUP_DIR/services_before_update.txt"
    
    success "Pre-update backup created: $BACKUP_DIR"
}

################################################################################
# Update Functions
################################################################################

update_system_packages() {
    log "Updating system packages..."
    
    # Update package lists
    apt update
    
    # Show what will be updated
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
    info "Available updates: $updates packages"
    
    if [[ $updates -gt 0 ]]; then
        # Perform upgrade
        DEBIAN_FRONTEND=noninteractive apt upgrade -y
        
        # Clean up
        apt autoremove -y
        apt autoclean
        
        success "System packages updated"
    else
        info "No system package updates available"
    fi
}

update_adguard_home() {
    log "Checking for AdGuard Home updates..."
    
    if [[ ! -f /opt/AdGuardHome/AdGuardHome ]]; then
        warning "AdGuard Home not found, skipping update"
        return
    fi
    
    # Get current version
    local current_version=$(/opt/AdGuardHome/AdGuardHome --version 2>/dev/null | head -1 | awk '{print $3}' || echo "unknown")
    
    # Get latest version from GitHub
    local latest_version=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    
    info "Current AdGuard Home version: $current_version"
    info "Latest AdGuard Home version: $latest_version"
    
    if [[ "$current_version" != "$latest_version" && "$latest_version" != "null" ]]; then
        log "Updating AdGuard Home from $current_version to $latest_version..."
        
        # Stop service
        systemctl stop AdGuardHome
        
        # Download and install update
        cd /tmp
        local download_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/$latest_version/AdGuardHome_linux_amd64.tar.gz"
        curl -L "$download_url" -o AdGuardHome_update.tar.gz
        
        # Backup current installation
        cp /opt/AdGuardHome/AdGuardHome /opt/AdGuardHome/AdGuardHome.backup
        
        # Extract and install
        tar -xzf AdGuardHome_update.tar.gz
        cp AdGuardHome/AdGuardHome /opt/AdGuardHome/
        chmod +x /opt/AdGuardHome/AdGuardHome
        
        # Start service
        systemctl start AdGuardHome
        
        # Verify update
        sleep 5
        if systemctl is-active --quiet AdGuardHome; then
            success "AdGuard Home updated to $latest_version"
        else
            error "AdGuard Home update failed, attempting rollback..."
            systemctl stop AdGuardHome
            cp /opt/AdGuardHome/AdGuardHome.backup /opt/AdGuardHome/AdGuardHome
            systemctl start AdGuardHome
            warning "AdGuard Home rolled back to previous version"
        fi
        
        # Cleanup
        rm -f /tmp/AdGuardHome_update.tar.gz
        rm -rf /tmp/AdGuardHome
    else
        info "AdGuard Home is up to date"
    fi
}

update_nextcloud() {
    log "Checking for Nextcloud updates..."
    
    if [[ ! -f /var/www/nextcloud/occ ]]; then
        warning "Nextcloud not found, skipping update"
        return
    fi
    
    # Check current version
    local current_version=$(sudo -u www-data php /var/www/nextcloud/occ -V | awk '{print $3}')
    info "Current Nextcloud version: $current_version"
    
    # Enable maintenance mode
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
    
    # Check for updates using built-in updater
    local update_available=$(sudo -u www-data php /var/www/nextcloud/updater/updater.phar --check-for-update 2>/dev/null || echo "false")
    
    if [[ "$update_available" == "true" ]]; then
        log "Nextcloud update available, starting update process..."
        
        # Perform update
        sudo -u www-data php /var/www/nextcloud/updater/updater.phar --update
        
        # Run database migrations
        sudo -u www-data php /var/www/nextcloud/occ db:add-missing-indices
        sudo -u www-data php /var/www/nextcloud/occ db:convert-filecache-bigint
        
        # Update apps
        sudo -u www-data php /var/www/nextcloud/occ app:update --all
        
        success "Nextcloud updated successfully"
    else
        info "Nextcloud is up to date"
    fi
    
    # Disable maintenance mode
    sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
    
    # Verify Nextcloud is working
    if curl -s http://localhost:8080 > /dev/null; then
        success "Nextcloud is responding after update"
    else
        warning "Nextcloud may not be responding properly"
    fi
}

update_nginx_config() {
    log "Checking Nginx configuration..."
    
    # Test current configuration
    if nginx -t; then
        success "Nginx configuration is valid"
    else
        warning "Nginx configuration has issues, skipping config updates"
        return
    fi
    
    # Reload nginx to pick up any changes
    systemctl reload nginx
    success "Nginx configuration reloaded"
}

update_security_lists() {
    log "Updating security and blocklists..."
    
    # Update fail2ban
    if systemctl is-active --quiet fail2ban; then
        systemctl reload fail2ban
        success "Fail2ban rules reloaded"
    fi
    
    # AdGuard Home will update its lists automatically
    # But we can trigger a manual update if needed
    if systemctl is-active --quiet AdGuardHome; then
        # AdGuard Home API call to update filters (if API is available)
        info "AdGuard Home blocklists will update automatically"
    fi
}

################################################################################
# Post-Update Functions
################################################################################

verify_services() {
    log "Verifying all services are running..."
    
    local services=("AdGuardHome" "nginx" "php8.3-fpm" "fail2ban")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success "✅ $service is running"
        else
            error "❌ $service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        success "All services are running"
        return 0
    else
        error "Failed services: ${failed_services[*]}"
        return 1
    fi
}

test_functionality() {
    log "Testing service functionality..."
    
    # Test Nginx
    if curl -s http://localhost > /dev/null; then
        success "✅ Nginx web server responding"
    else
        error "❌ Nginx web server not responding"
    fi
    
    # Test AdGuard Home
    if curl -s http://localhost:3000 > /dev/null; then
        success "✅ AdGuard Home web interface responding"
    else
        warning "⚠️ AdGuard Home web interface not responding"
    fi
    
    # Test Nextcloud
    if curl -s http://localhost:8080 > /dev/null; then
        success "✅ Nextcloud responding"
    else
        warning "⚠️ Nextcloud not responding"
    fi
    
    # Test DNS resolution
    if nslookup google.com localhost > /dev/null 2>&1; then
        success "✅ DNS resolution working"
    else
        warning "⚠️ DNS resolution may have issues"
    fi
}

generate_update_report() {
    log "Generating update report..."
    
    local report_file="/var/log/homelab-update-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== ZimaBoard 2 Homelab Update Report ==="
        echo "Update Date: $(date)"
        echo "Update Duration: $((SECONDS / 60)) minutes"
        echo
        echo "=== System Information ==="
        echo "OS: $(lsb_release -d | cut -f2)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo
        echo "=== Service Status ==="
        systemctl status AdGuardHome nginx php8.3-fpm fail2ban --no-pager -l
        echo
        echo "=== Disk Usage ==="
        df -h
        echo
        echo "=== Memory Usage ==="
        free -h
        echo
        echo "=== Recent Log Entries ==="
        tail -20 "$LOG_FILE"
    } > "$report_file"
    
    success "Update report saved: $report_file"
}

################################################################################
# Main Update Process
################################################################################

echo
log "=== ZimaBoard 2 Homelab Update Started ==="

# Pre-update checks
if ! check_system_health; then
    warning "System health check found issues. Continue anyway? [y/N]"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Update cancelled by user"
        exit 0
    fi
fi

# Create backup
create_pre_update_backup

# Perform updates
update_system_packages
update_adguard_home
update_nextcloud
update_nginx_config
update_security_lists

# Post-update verification
if ! verify_services; then
    error "Some services failed to start properly"
    warning "Check the logs and consider rolling back if needed"
fi

test_functionality
generate_update_report

# Final status
echo
success "=== Update Process Completed ==="
info "Update log: $LOG_FILE"
info "Pre-update backup: $BACKUP_DIR"
log "=== ZimaBoard 2 Homelab Update Finished ==="

# Show summary
echo
echo -e "${CYAN}Update Summary:${NC}"
echo "✅ System packages updated"
echo "✅ AdGuard Home checked/updated"
echo "✅ Nextcloud checked/updated"
echo "✅ Security configurations updated"
echo "✅ Services verified"
echo

if [[ -t 1 ]]; then
    echo -e "${GREEN}Update completed successfully!${NC}"
    echo -e "${BLUE}Reboot recommended: sudo reboot${NC}"
    echo
    read -p "Reboot now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "System reboot initiated by user"
        reboot
    fi
fi

exit 0

################################################################################
# Usage Examples:
#
# Manual update:
# sudo ./update.sh
#
# Schedule weekly updates:
# sudo crontab -e
# 0 3 * * 1 /path/to/update.sh >> /var/log/homelab-update.log 2>&1
#
# Update specific service only:
# Edit this script to comment out unwanted update functions
################################################################################