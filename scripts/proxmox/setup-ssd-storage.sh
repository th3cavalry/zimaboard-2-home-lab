#!/bin/bash

# ZimaBoard 2 SSD Storage Setup Script
# Configures the 2TB SSD for NAS and backup storage

set -e

echo "📀 ZimaBoard 2 SSD Storage Setup"
echo "================================="
echo "Setting up 2TB SSD for Seafile NAS and backup storage..."
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

# Detect the 2TB SSD (usually /dev/sdb on ZimaBoard 2)
SSD_DEVICE="/dev/sdb"
if [[ ! -b "$SSD_DEVICE" ]]; then
    echo "❌ SSD device $SSD_DEVICE not found"
    echo "Available devices:"
    lsblk
    exit 1
fi

echo "✅ Found SSD: $SSD_DEVICE"
echo "Current partition table:"
lsblk $SSD_DEVICE
echo ""

# Confirm before proceeding
read -p "⚠️  This will ERASE all data on $SSD_DEVICE. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted by user"
    exit 1
fi

echo "🔧 Creating partition table..."
# Create GPT partition table
parted -s $SSD_DEVICE mklabel gpt

# Create partitions:
# 1TB for Seafile NAS data
# 1TB for backups and expansion
echo "🔧 Creating partitions..."
parted -s $SSD_DEVICE mkpart primary ext4 0% 50%
parted -s $SSD_DEVICE mkpart primary ext4 50% 100%

# Wait for system to recognize new partitions
sleep 2

# Format partitions
echo "🔧 Formatting partitions..."
mkfs.ext4 -F ${SSD_DEVICE}1 -L "seafile-data"
mkfs.ext4 -F ${SSD_DEVICE}2 -L "backup-storage"

# Create mount points
echo "🔧 Creating mount points..."
mkdir -p /mnt/seafile-data
mkdir -p /mnt/backup-storage

# Get UUIDs for fstab
SEAFILE_UUID=$(blkid -s UUID -o value ${SSD_DEVICE}1)
BACKUP_UUID=$(blkid -s UUID -o value ${SSD_DEVICE}2)

# Add to fstab
echo "🔧 Adding to /etc/fstab..."
cp /etc/fstab /etc/fstab.backup
echo "" >> /etc/fstab
echo "# ZimaBoard 2 SSD Storage" >> /etc/fstab
echo "UUID=$SEAFILE_UUID /mnt/seafile-data ext4 defaults,noatime 0 2" >> /etc/fstab
echo "UUID=$BACKUP_UUID /mnt/backup-storage ext4 defaults,noatime 0 2" >> /etc/fstab

# Mount the partitions
echo "🔧 Mounting partitions..."
mount -a

# Set permissions
chmod 755 /mnt/seafile-data
chmod 755 /mnt/backup-storage

echo ""
echo "✅ SSD Storage Setup Complete!"
echo "=============================="
echo "• Seafile NAS storage: /mnt/seafile-data (1TB)"
echo "• Backup storage: /mnt/backup-storage (1TB)"
echo ""
echo "Storage usage:"
df -h /mnt/seafile-data /mnt/backup-storage
echo ""
echo "🔧 Ready for service deployment!"
