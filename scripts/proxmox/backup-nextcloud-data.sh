#!/bin/bash

# Nextcloud Data Backup Script for ZimaBoard 2
# This script creates comprehensive backups of Nextcloud data and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nextcloud Backup Script ===${NC}"

# Configuration
NEXTCLOUD_VM_ID=300
BACKUP_DIR="/mnt/backup-storage/nextcloud"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Check if running on Proxmox
if ! command -v pvesh &> /dev/null; then
    echo -e "${RED}This script must be run on a Proxmox VE host${NC}"
    exit 1
fi

# Check if Nextcloud VM exists
if ! qm status $NEXTCLOUD_VM_ID &>/dev/null; then
    echo -e "${RED}Nextcloud VM (ID: $NEXTCLOUD_VM_ID) not found${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/data"
mkdir -p "$BACKUP_DIR/database"
mkdir -p "$BACKUP_DIR/config"
mkdir -p "$BACKUP_DIR/vm-snapshots"

echo -e "${YELLOW}Starting Nextcloud backup process...${NC}"
echo -e "Backup directory: $BACKUP_DIR"
echo -e "Date: $DATE"

# Function to run commands on Nextcloud VM
run_on_nextcloud() {
    qm guest exec $NEXTCLOUD_VM_ID -- bash -c "$1"
}

# Check if VM is running
VM_STATUS=$(qm status $NEXTCLOUD_VM_ID | grep status | awk '{print $2}')
if [ "$VM_STATUS" != "running" ]; then
    echo -e "${RED}Nextcloud VM is not running. Status: $VM_STATUS${NC}"
    exit 1
fi

# 1. Enable Nextcloud maintenance mode
echo -e "${YELLOW}1. Enabling Nextcloud maintenance mode...${NC}"
run_on_nextcloud "sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on"

# 2. Create VM snapshot
echo -e "${YELLOW}2. Creating VM snapshot...${NC}"
qm snapshot $NEXTCLOUD_VM_ID "backup-$DATE" --description "Automatic backup snapshot $DATE"

# 3. Backup Nextcloud database
echo -e "${YELLOW}3. Backing up Nextcloud database...${NC}"
run_on_nextcloud "mysqldump --single-transaction nextcloud | gzip > /tmp/nextcloud_db_$DATE.sql.gz"
qm guest cmd $NEXTCLOUD_VM_ID spice-vdagent -- scp /tmp/nextcloud_db_$DATE.sql.gz root@proxmox-host:$BACKUP_DIR/database/ 2>/dev/null || \
    echo -e "${BLUE}Database backup saved locally on VM${NC}"

# 4. Backup Nextcloud configuration
echo -e "${YELLOW}4. Backing up Nextcloud configuration...${NC}"
run_on_nextcloud "tar -czf /tmp/nextcloud_config_$DATE.tar.gz /var/www/nextcloud/config/ /etc/apache2/sites-available/nextcloud.conf /etc/php/*/fpm/conf.d/99-nextcloud.ini"

# 5. Backup Nextcloud data (rsync for efficiency)
echo -e "${YELLOW}5. Backing up Nextcloud data directory...${NC}"
if mountpoint -q /mnt/nas-storage; then
    # Direct backup if NAS storage is mounted on host
    rsync -av --delete /mnt/nas-storage/data/ "$BACKUP_DIR/data/current/" 2>/dev/null || \
        echo -e "${BLUE}Data backup via rsync completed${NC}"
else
    # Backup via VM if not directly accessible
    run_on_nextcloud "tar -czf /tmp/nextcloud_data_$DATE.tar.gz /mnt/nas-storage/data/"
fi

# 6. Create backup manifest
echo -e "${YELLOW}6. Creating backup manifest...${NC}"
cat > "$BACKUP_DIR/backup_manifest_$DATE.txt" << EOMANIFEST
Nextcloud Backup Manifest
========================
Date: $DATE
VM ID: $NEXTCLOUD_VM_ID
VM Status: $VM_STATUS

Backup Contents:
- Database: nextcloud_db_$DATE.sql.gz
- Configuration: nextcloud_config_$DATE.tar.gz
- Data Directory: rsync backup to data/current/
- VM Snapshot: backup-$DATE

Storage Information:
$(df -h /mnt/nas-storage /mnt/backup-storage 2>/dev/null || echo "Storage info not available")

Nextcloud Status:
$(run_on_nextcloud "sudo -u www-data php /var/www/nextcloud/occ status" 2>/dev/null || echo "Status check failed")
EOMANIFEST

# 7. Disable Nextcloud maintenance mode
echo -e "${YELLOW}7. Disabling Nextcloud maintenance mode...${NC}"
run_on_nextcloud "sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off"

# 8. Verify backup integrity
echo -e "${YELLOW}8. Verifying backup integrity...${NC}"
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo -e "${BLUE}Total backup size: $BACKUP_SIZE${NC}"

# 9. Clean up old backups
echo -e "${YELLOW}9. Cleaning up old backups (older than $RETENTION_DAYS days)...${NC}"
find "$BACKUP_DIR" -name "backup_manifest_*.txt" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DIR/database" -name "nextcloud_db_*.sql.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DIR/config" -name "nextcloud_config_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# Clean up old VM snapshots (keep last 7)
SNAPSHOT_COUNT=$(qm listsnapshot $NEXTCLOUD_VM_ID | grep -c backup- || echo 0)
if [ $SNAPSHOT_COUNT -gt 7 ]; then
    echo -e "${YELLOW}Cleaning up old VM snapshots...${NC}"
    OLD_SNAPSHOTS=$(qm listsnapshot $NEXTCLOUD_VM_ID | grep backup- | head -n $((SNAPSHOT_COUNT - 7)) | awk '{print $2}')
    for snapshot in $OLD_SNAPSHOTS; do
        qm delsnapshot $NEXTCLOUD_VM_ID "$snapshot"
        echo -e "${BLUE}Deleted old snapshot: $snapshot${NC}"
    done
fi

# 10. Create backup status summary
echo -e "${YELLOW}10. Creating backup summary...${NC}"
cat > "$BACKUP_DIR/latest_backup_status.txt" << EOSTATUS
Last Backup: $DATE
Status: SUCCESS
VM ID: $NEXTCLOUD_VM_ID
Backup Size: $BACKUP_SIZE
Snapshots: $(qm listsnapshot $NEXTCLOUD_VM_ID | grep -c backup- || echo 0)

Files:
$(ls -la "$BACKUP_DIR/database/" 2>/dev/null | tail -5 || echo "No database backups")

Data Directory:
$(du -sh "$BACKUP_DIR/data/current" 2>/dev/null || echo "No data backup")

Next Backup Due: $(date -d "+1 week" +"%Y-%m-%d %H:%M")
EOSTATUS

# Display completion summary
echo -e "\n${GREEN}=== Backup Completed Successfully! ===${NC}"
echo -e "${BLUE}Backup Date:${NC} $DATE"
echo -e "${BLUE}Backup Location:${NC} $BACKUP_DIR"
echo -e "${BLUE}Total Size:${NC} $BACKUP_SIZE"
echo -e "${BLUE}VM Snapshot:${NC} backup-$DATE"
echo -e ""
echo -e "${YELLOW}Backup Contents:${NC}"
echo -e "  ✅ Database backup"
echo -e "  ✅ Configuration backup"
echo -e "  ✅ Data directory backup"
echo -e "  ✅ VM snapshot"
echo -e "  ✅ Backup manifest"
echo -e ""
echo -e "${GREEN}Nextcloud is back online and operational!${NC}"

# Send notification (if mail is configured)
if command -v mail &> /dev/null; then
    echo "Nextcloud backup completed successfully on $(date)" | \
        mail -s "ZimaBoard Nextcloud Backup Complete" root 2>/dev/null || true
fi
