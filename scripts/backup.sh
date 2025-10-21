#!/bin/bash
################################################################################
# ZimaBoard 2 Ultimate Homelab - Backup Script
# 
# This script creates comprehensive backups of all homelab data and configurations
# Designed for automated scheduling via cron
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKUP_BASE_DIR="/mnt/ssd-data/backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_DATE"
RETENTION_DAYS=30
LOG_FILE="/var/log/homelab-backup.log"

# Services and directories to backup
NEXTCLOUD_DATA="/mnt/ssd-data/nextcloud"
ADGUARD_CONFIG="/opt/AdGuardHome/conf"
NGINX_CONFIG="/etc/nginx"
WEB_ROOT="/var/www"

# Logging function
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

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting backup process to: $BACKUP_DIR"

################################################################################
# Backup Functions
################################################################################

backup_nextcloud() {
    log "Backing up Nextcloud data..."
    
    if [[ -d "$NEXTCLOUD_DATA" ]]; then
        # Put Nextcloud in maintenance mode
        if [[ -f /var/www/nextcloud/occ ]]; then
            sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
            info "Nextcloud maintenance mode enabled"
        fi
        
        # Backup data
        tar -czf "$BACKUP_DIR/nextcloud_data.tar.gz" -C "$(dirname "$NEXTCLOUD_DATA")" "$(basename "$NEXTCLOUD_DATA")"
        
        # Backup database (if SQLite)
        if [[ -f /var/www/nextcloud/data/owncloud.db ]]; then
            cp /var/www/nextcloud/data/owncloud.db "$BACKUP_DIR/nextcloud_database.db"
        fi
        
        # Backup config
        if [[ -d /var/www/nextcloud/config ]]; then
            tar -czf "$BACKUP_DIR/nextcloud_config.tar.gz" -C /var/www/nextcloud config
        fi
        
        # Disable maintenance mode
        if [[ -f /var/www/nextcloud/occ ]]; then
            sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
            info "Nextcloud maintenance mode disabled"
        fi
        
        success "Nextcloud backup completed"
    else
        warning "Nextcloud data directory not found"
    fi
}

backup_adguard() {
    log "Backing up AdGuard Home configuration..."
    
    if [[ -d "$ADGUARD_CONFIG" ]]; then
        tar -czf "$BACKUP_DIR/adguard_config.tar.gz" -C "$(dirname "$ADGUARD_CONFIG")" "$(basename "$ADGUARD_CONFIG")"
        success "AdGuard Home backup completed"
    else
        warning "AdGuard Home configuration directory not found"
    fi
}

backup_nginx() {
    log "Backing up Nginx configuration..."
    
    if [[ -d "$NGINX_CONFIG" ]]; then
        tar -czf "$BACKUP_DIR/nginx_config.tar.gz" -C "$(dirname "$NGINX_CONFIG")" "$(basename "$NGINX_CONFIG")"
        success "Nginx backup completed"
    else
        warning "Nginx configuration directory not found"
    fi
}

backup_web_files() {
    log "Backing up web files..."
    
    if [[ -d "$WEB_ROOT" ]]; then
        tar -czf "$BACKUP_DIR/web_files.tar.gz" -C "$(dirname "$WEB_ROOT")" "$(basename "$WEB_ROOT")"
        success "Web files backup completed"
    else
        warning "Web root directory not found"
    fi
}

backup_system_config() {
    log "Backing up system configuration..."
    
    # UFW rules
    if command -v ufw &> /dev/null; then
        ufw status verbose > "$BACKUP_DIR/ufw_rules.txt"
    fi
    
    # Fail2ban configuration
    if [[ -d /etc/fail2ban ]]; then
        tar -czf "$BACKUP_DIR/fail2ban_config.tar.gz" -C /etc fail2ban
    fi
    
    # Crontab
    crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || echo "No crontab found" > "$BACKUP_DIR/crontab.txt"
    
    # Installed packages
    dpkg --get-selections > "$BACKUP_DIR/installed_packages.txt"
    
    # System information
    {
        echo "=== System Information ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "OS: $(lsb_release -d | cut -f2)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo
        echo "=== Storage Usage ==="
        df -h
        echo
        echo "=== Memory Usage ==="
        free -h
        echo
        echo "=== CPU Information ==="
        lscpu | grep -E "(Model|CPU|Thread|Core)"
        echo
        echo "=== Network Configuration ==="
        ip addr show
        echo
        echo "=== Running Services ==="
        systemctl list-units --type=service --state=running
    } > "$BACKUP_DIR/system_info.txt"
    
    success "System configuration backup completed"
}

backup_homelab_scripts() {
    log "Backing up homelab scripts..."
    
    # This script
    cp "$0" "$BACKUP_DIR/backup_script.sh"
    
    # Status script
    if [[ -f /usr/local/bin/homelab-status ]]; then
        cp /usr/local/bin/homelab-status "$BACKUP_DIR/homelab-status.sh"
    fi
    
    # Install script (if available)
    if [[ -f /root/install.sh ]]; then
        cp /root/install.sh "$BACKUP_DIR/install_script.sh"
    fi
    
    success "Homelab scripts backup completed"
}

create_backup_manifest() {
    log "Creating backup manifest..."
    
    {
        echo "=== ZimaBoard 2 Homelab Backup Manifest ==="
        echo "Backup Date: $(date)"
        echo "Backup Directory: $BACKUP_DIR"
        echo "Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
        echo
        echo "=== Backup Contents ==="
        ls -lah "$BACKUP_DIR"
        echo
        echo "=== File Checksums ==="
        cd "$BACKUP_DIR"
        sha256sum * 2>/dev/null || true
        echo
        echo "=== Service Status at Backup Time ==="
        systemctl is-active AdGuardHome nginx php8.3-fpm fail2ban 2>/dev/null || true
    } > "$BACKUP_DIR/BACKUP_MANIFEST.txt"
    
    success "Backup manifest created"
}

cleanup_old_backups() {
    log "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
    
    find "$BACKUP_BASE_DIR" -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
    
    # Count remaining backups
    local backup_count=$(find "$BACKUP_BASE_DIR" -type d -name "20*" | wc -l)
    info "Remaining backups: $backup_count"
    
    success "Old backup cleanup completed"
}

################################################################################
# Main Backup Process
################################################################################

# Start backup
echo
log "=== ZimaBoard 2 Homelab Backup Started ==="

# Perform backups
backup_nextcloud
backup_adguard
backup_nginx
backup_web_files
backup_system_config
backup_homelab_scripts
create_backup_manifest

# Cleanup old backups
cleanup_old_backups

# Final statistics
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
TOTAL_BACKUPS=$(find "$BACKUP_BASE_DIR" -type d -name "20*" | wc -l)

echo
success "=== Backup Completed Successfully ==="
info "Backup location: $BACKUP_DIR"
info "Backup size: $BACKUP_SIZE"
info "Total backups: $TOTAL_BACKUPS"
log "=== ZimaBoard 2 Homelab Backup Finished ==="

# If running interactively, show backup contents
if [[ -t 1 ]]; then
    echo
    echo -e "${CYAN}Backup contents:${NC}"
    ls -lah "$BACKUP_DIR"
    echo
    echo -e "${GREEN}Backup completed successfully!${NC}"
    echo -e "${BLUE}Location: $BACKUP_DIR${NC}"
fi

exit 0

################################################################################
# Usage Examples:
#
# Manual backup:
# sudo ./backup.sh
#
# Schedule daily backups at 2 AM:
# sudo crontab -e
# 0 2 * * * /path/to/backup.sh >> /var/log/homelab-backup.log 2>&1
#
# Schedule weekly backups:
# 0 2 * * 0 /path/to/backup.sh >> /var/log/homelab-backup.log 2>&1
#
# Restore from backup:
# See restore.sh script or documentation
################################################################################