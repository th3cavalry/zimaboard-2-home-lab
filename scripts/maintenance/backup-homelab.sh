#!/bin/bash

# ZimaBoard 2 Homelab Backup Script
# Comprehensive backup solution for all critical data and configurations

set -euo pipefail

# Configuration
BACKUP_BASE="/mnt/ssd-data/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE}/${TIMESTAMP}"
RETENTION_DAYS=30
LOG_FILE="/var/log/homelab-backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
   exit 1
fi

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"/{config,data,system,database}
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        error "Failed to create backup directory"
        exit 1
    fi
    success "Backup directory created successfully"
}

# Backup system configurations
backup_system_config() {
    log "Backing up system configurations..."
    
    # Network configuration
    if [[ -d /etc/netplan ]]; then
        cp -r /etc/netplan "$BACKUP_DIR/config/"
        success "Network configuration backed up"
    fi
    
    # SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config "$BACKUP_DIR/config/"
        success "SSH configuration backed up"
    fi
    
    # Firewall rules
    ufw status verbose > "$BACKUP_DIR/config/ufw-status.txt" 2>/dev/null || true
    
    # Crontab entries
    crontab -l > "$BACKUP_DIR/config/root-crontab.txt" 2>/dev/null || true
    
    # Installed packages list
    dpkg --get-selections > "$BACKUP_DIR/system/installed-packages.txt"
    apt-mark showmanual > "$BACKUP_DIR/system/manual-packages.txt"
    
    success "System configuration backup completed"
}

# Backup AdGuard Home
backup_adguard() {
    log "Backing up AdGuard Home..."
    
    if [[ -d /opt/AdGuardHome ]]; then
        # Stop AdGuard temporarily for consistent backup
        systemctl stop AdGuardHome || warning "Could not stop AdGuardHome service"
        
        # Backup configuration and data
        cp -r /opt/AdGuardHome "$BACKUP_DIR/config/"
        
        # Restart AdGuard
        systemctl start AdGuardHome || error "Failed to restart AdGuardHome"
        
        success "AdGuard Home backup completed"
    else
        warning "AdGuard Home not found, skipping backup"
    fi
}

# Backup Nextcloud
backup_nextcloud() {
    log "Backing up Nextcloud..."
    
    if [[ -d /var/www/nextcloud ]]; then
        # Enable maintenance mode
        sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on || warning "Could not enable maintenance mode"
        
        # Backup Nextcloud files (excluding data for space efficiency)
        log "Backing up Nextcloud application files..."
        rsync -av --exclude='data' /var/www/nextcloud/ "$BACKUP_DIR/data/nextcloud-app/" || error "Failed to backup Nextcloud app"
        
        # Backup Nextcloud configuration
        if [[ -f /var/www/nextcloud/config/config.php ]]; then
            cp /var/www/nextcloud/config/config.php "$BACKUP_DIR/config/"
            success "Nextcloud configuration backed up"
        fi
        
        # Backup Nextcloud database (SQLite)
        if [[ -f /var/www/nextcloud/data/nextcloud.db ]]; then
            cp /var/www/nextcloud/data/nextcloud.db "$BACKUP_DIR/database/"
            success "Nextcloud database backed up"
        fi
        
        # Create list of user data files (for reference)
        if [[ -d /mnt/ssd-data/nextcloud ]]; then
            find /mnt/ssd-data/nextcloud -type f > "$BACKUP_DIR/data/nextcloud-files-list.txt"
            du -sh /mnt/ssd-data/nextcloud > "$BACKUP_DIR/data/nextcloud-data-size.txt"
            log "Nextcloud data file list created (actual files not backed up due to size)"
        fi
        
        # Disable maintenance mode
        sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off || warning "Could not disable maintenance mode"
        
        success "Nextcloud backup completed"
    else
        warning "Nextcloud not found, skipping backup"
    fi
}

# Backup Nginx configuration
backup_nginx() {
    log "Backing up Nginx configuration..."
    
    if [[ -d /etc/nginx ]]; then
        cp -r /etc/nginx "$BACKUP_DIR/config/"
        
        # Backup custom web files
        if [[ -d /var/www/html ]]; then
            cp -r /var/www/html "$BACKUP_DIR/data/"
        fi
        
        success "Nginx configuration and web files backed up"
    else
        warning "Nginx not found, skipping backup"
    fi
}

# Create system information snapshot
backup_system_info() {
    log "Creating system information snapshot..."
    
    # System information
    {
        echo "=== System Information ==="
        hostnamectl
        echo
        
        echo "=== Memory Usage ==="
        free -h
        echo
        
        echo "=== Disk Usage ==="
        df -h
        echo
        
        echo "=== Block Devices ==="
        lsblk
        echo
        
        echo "=== Network Interfaces ==="
        ip addr show
        echo
        
        echo "=== Running Services ==="
        systemctl list-units --type=service --state=running
        echo
        
        echo "=== Process List ==="
        ps aux --sort=-%cpu | head -20
        echo
        
    } > "$BACKUP_DIR/system/system-info.txt"
    
    success "System information snapshot created"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    if [[ -d "$BACKUP_BASE" ]]; then
        find "$BACKUP_BASE" -type d -name "20*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
        
        # Count remaining backups
        BACKUP_COUNT=$(find "$BACKUP_BASE" -maxdepth 1 -type d -name "20*" | wc -l)
        success "Cleanup completed. $BACKUP_COUNT backups remaining"
    fi
}

# Create backup summary
create_backup_summary() {
    log "Creating backup summary..."
    
    {
        echo "ZimaBoard 2 Homelab Backup Summary"
        echo "=================================="
        echo "Backup Date: $(date)"
        echo "Backup Location: $BACKUP_DIR"
        echo "Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
        echo
        
        echo "Backed up components:"
        echo "- System configuration files"
        echo "- AdGuard Home configuration and data"
        echo "- Nextcloud application and database"
        echo "- Nginx configuration and web files"
        echo "- System information snapshot"
        echo
        
        echo "File count by category:"
        find "$BACKUP_DIR/config" -type f | wc -l | xargs echo "- Configuration files:"
        find "$BACKUP_DIR/data" -type f | wc -l | xargs echo "- Data files:"
        find "$BACKUP_DIR/system" -type f | wc -l | xargs echo "- System files:"
        find "$BACKUP_DIR/database" -type f | wc -l | xargs echo "- Database files:"
        
    } > "$BACKUP_DIR/backup-summary.txt"
    
    success "Backup summary created"
}

# Main backup function
main() {
    log "Starting ZimaBoard 2 Homelab backup..."
    log "Backup will be stored in: $BACKUP_DIR"
    
    create_backup_dir
    backup_system_config
    backup_adguard
    backup_nextcloud  
    backup_nginx
    backup_system_info
    create_backup_summary
    cleanup_old_backups
    
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    success "Backup completed successfully!"
    success "Total backup size: $BACKUP_SIZE"
    success "Backup location: $BACKUP_DIR"
    
    log "Backup process finished"
}

# Trap to handle script interruption
trap 'error "Backup interrupted"; exit 1' INT TERM

# Run main function
main "$@"
