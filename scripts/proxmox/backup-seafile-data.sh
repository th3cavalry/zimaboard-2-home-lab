#!/bin/bash

# ZimaBoard 2 Homelab - Seafile Data Backup Script
# Optimized for performance with incremental backups

set -e

echo "📁 Seafile NAS Data Backup"
echo "=========================="
echo "Creating optimized backup of Seafile data..."
echo ""

BACKUP_DIR="/mnt/backup-storage/seafile-backups"
DATE=$(date +"%Y%m%d_%H%M%S")
SEAFILE_DATA="/mnt/seafile-data"

# Check if Seafile data exists
if [[ ! -d "$SEAFILE_DATA" ]]; then
    echo "❌ Seafile data directory not found: $SEAFILE_DATA"
    exit 1
fi

# Create backup directory
mkdir -p $BACKUP_DIR

echo "📦 Backup details:"
echo "• Source: $SEAFILE_DATA"
echo "• Destination: $BACKUP_DIR"
echo "• Date: $DATE"
echo ""

# Calculate source size
TOTAL_SIZE=$(du -sh $SEAFILE_DATA | awk '{print $1}')
echo "📊 Source data size: $TOTAL_SIZE"

# Create incremental backup using rsync
echo "�� Creating incremental backup..."
rsync -av --progress \
    --delete \
    --backup --backup-dir="$BACKUP_DIR/deleted-$DATE" \
    --exclude='.*' \
    --exclude='Thumbs.db' \
    --exclude='.DS_Store' \
    "$SEAFILE_DATA/" \
    "$BACKUP_DIR/current/"

# Create compressed snapshot
echo "🗜️  Creating compressed snapshot..."
tar -czf "$BACKUP_DIR/seafile-snapshot-$DATE.tar.gz" -C "$BACKUP_DIR" current/

# Update latest symlink
ln -sfn "$BACKUP_DIR/seafile-snapshot-$DATE.tar.gz" "$BACKUP_DIR/latest-snapshot.tar.gz"

echo ""

# Clean up old snapshots (keep 14 days for NAS data)
echo "🧹 Cleaning up old snapshots (14-day retention)..."
find $BACKUP_DIR -name "seafile-snapshot-*.tar.gz" -mtime +14 -delete
find $BACKUP_DIR -name "deleted-*" -mtime +14 -exec rm -rf {} \; 2>/dev/null || true

echo ""

# Show backup summary
BACKUP_SIZE=$(du -sh $BACKUP_DIR | awk '{print $1}')
SNAPSHOT_SIZE=$(du -sh "$BACKUP_DIR/seafile-snapshot-$DATE.tar.gz" | awk '{print $1}')

echo "✅ Seafile backup completed!"
echo "📊 Backup Summary:"
echo "• Total backup size: $BACKUP_SIZE"
echo "• Latest snapshot: $SNAPSHOT_SIZE"
echo "• Retention: 14 days"
echo "• Location: $BACKUP_DIR"

echo ""
echo "💡 Restore commands:"
echo "• Full restore: tar -xzf $BACKUP_DIR/latest-snapshot.tar.gz -C /mnt/"
echo "• Incremental: rsync -av $BACKUP_DIR/current/ /mnt/seafile-data/"
