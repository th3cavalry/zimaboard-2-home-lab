#!/bin/bash

# ZimaBoard 2 Homelab - Snapshot Cleanup Script
# Automated retention policy management

set -e

echo "🧹 ZimaBoard 2 Homelab - Snapshot Cleanup"
echo "=========================================="
echo "Cleaning up old snapshots and backups..."
echo ""

BACKUP_DIR="/mnt/backup-storage/snapshots"
RETENTION_DAYS=7

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "⚠️  Backup directory not found: $BACKUP_DIR"
    echo "No cleanup needed."
    exit 0
fi

echo "📁 Backup directory: $BACKUP_DIR"
echo "🗓️  Retention policy: $RETENTION_DAYS days"
echo ""

# Show current backup size
CURRENT_SIZE=$(du -sh $BACKUP_DIR | awk '{print $1}')
echo "📊 Current backup size: $CURRENT_SIZE"

# Count files before cleanup
BEFORE_COUNT=$(find $BACKUP_DIR -name "*.tar.gz" | wc -l)
echo "📦 Files before cleanup: $BEFORE_COUNT"

echo ""
echo "🔍 Finding files older than $RETENTION_DAYS days..."

# Find and list old files
OLD_FILES=$(find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS)
if [[ -n "$OLD_FILES" ]]; then
    echo "Files to be removed:"
    echo "$OLD_FILES"
    echo ""
    
    # Calculate space to be freed
    SPACE_TO_FREE=$(find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -exec du -ch {} + | tail -1 | awk '{print $1}')
    echo "💾 Space to be freed: $SPACE_TO_FREE"
    echo ""
    
    # Confirm deletion
    read -p "🗑️  Proceed with deletion? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Delete old files
        find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
        find $BACKUP_DIR -name "vzdump-*.tar.gz" -mtime +$RETENTION_DAYS -delete
        
        # Clean up empty directories
        find $BACKUP_DIR -type d -empty -delete 2>/dev/null || true
        
        echo "✅ Old files removed successfully"
    else
        echo "❌ Cleanup cancelled by user"
        exit 0
    fi
else
    echo "✅ No files older than $RETENTION_DAYS days found"
fi

echo ""

# Show results
AFTER_COUNT=$(find $BACKUP_DIR -name "*.tar.gz" | wc -l)
AFTER_SIZE=$(du -sh $BACKUP_DIR | awk '{print $1}')

echo "📊 Cleanup Summary:"
echo "• Files removed: $((BEFORE_COUNT - AFTER_COUNT))"
echo "• Files remaining: $AFTER_COUNT"
echo "• Size after cleanup: $AFTER_SIZE"
echo "• Space freed: $(echo "$CURRENT_SIZE - $AFTER_SIZE" | bc 2>/dev/null || echo "Unknown")"

echo ""
echo "🗂️  Current backup files:"
ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null | awk '{print "• " $9 " (" $5 ") - " $6 " " $7 " " $8}' || echo "• No backup files found"

echo ""
echo "✅ Snapshot cleanup completed!"
echo "💡 Next automated cleanup: $(date -d "+$RETENTION_DAYS days" '+%Y-%m-%d')"
