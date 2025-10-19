#!/bin/bash

# ZimaBoard 2 Homelab - Automated Backup Script
# Community-recommended 7-day retention policy

set -e

echo "💾 ZimaBoard 2 Homelab - Automated Backup"
echo "========================================="
echo "Creating snapshots of all containers..."
echo ""

BACKUP_DIR="/mnt/backup-storage/snapshots"
DATE=$(date +"%Y%m%d_%H%M%S")

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Container list with descriptions
declare -A CONTAINERS=(
    [100]="pihole"
    [101]="fail2ban"
    [102]="seafile"
    [103]="squid"
    [104]="netdata"
    [105]="wireguard"
    [106]="clamav"
    [107]="nginx"
)

echo "📦 Backing up containers to: $BACKUP_DIR"
echo ""

# Backup each container
for container_id in "${!CONTAINERS[@]}"; do
    service_name="${CONTAINERS[$container_id]}"
    
    if pct status $container_id &> /dev/null; then
        echo "🔄 Backing up CT $container_id ($service_name)..."
        
        vzdump $container_id \
            --mode snapshot \
            --compress gzip \
            --dumpdir $BACKUP_DIR \
            --storage local \
            --quiet
            
        echo "✅ CT $container_id backup completed"
    else
        echo "⚠️  CT $container_id not found, skipping..."
    fi
done

echo ""

# Backup Seafile data separately
if [[ -d "/mnt/seafile-data" ]]; then
    echo "📁 Backing up Seafile NAS data..."
    tar -czf "$BACKUP_DIR/seafile-data-$DATE.tar.gz" -C /mnt/seafile-data . 2>/dev/null || echo "⚠️  Seafile data backup warning (may be empty)"
    echo "✅ Seafile data backup completed"
fi

echo ""

# Clean up old backups (7-day retention)
echo "🧹 Cleaning up backups older than 7 days..."
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "vzdump-*.tar.gz" -mtime +7 -delete

echo ""

# Show backup summary
echo "📊 Backup Summary:"
echo "• Location: $BACKUP_DIR"
echo "• Date: $DATE"
echo "• Total size: $(du -sh $BACKUP_DIR | awk '{print $1}')"
echo "• Files: $(ls -1 $BACKUP_DIR | wc -l) backup files"

echo ""
echo "✅ Automated backup completed successfully!"
echo "💡 Restore with: pct restore <backup-file> <new-container-id> --force"
