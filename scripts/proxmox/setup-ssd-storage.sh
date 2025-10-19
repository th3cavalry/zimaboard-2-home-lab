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

# Detect the 2TB SSD dynamically (can be /dev/sda or /dev/sdb)
echo "🔍 Detecting 2TB SSD device..."
SSD_DEVICE=""

# Check common SSD device paths
for device in /dev/sda /dev/sdb /dev/sdc; do
    if [[ -b "$device" ]]; then
        # Get device size in GB
        size_bytes=$(lsblk -b -d -n -o SIZE "$device" 2>/dev/null || echo 0)
        size_gb=$((size_bytes / 1024 / 1024 / 1024))
        
        echo "Found device: $device (${size_gb}GB)"
        
        # Look for devices between 1800-2200GB (allowing for manufacturer differences)
        if [[ $size_gb -gt 1800 && $size_gb -lt 2200 ]]; then
            SSD_DEVICE="$device"
            echo "✅ Selected 2TB SSD: $SSD_DEVICE (${size_gb}GB)"
            break
        fi
    fi
done

if [[ -z "$SSD_DEVICE" ]]; then
    echo "❌ No 2TB SSD device found automatically"
    echo "Available devices:"
    lsblk
    echo ""
    echo "Please manually specify the SSD device path:"
    echo "Example: export SSD_DEVICE=/dev/sda && $0"
    exit 1
fi

# Safety check - make sure we're not targeting eMMC
if [[ "$SSD_DEVICE" == *"mmcblk"* ]]; then
    echo "❌ Error: Selected device appears to be eMMC storage!"
    echo "This script is designed for SSD storage only."
    echo "eMMC device detected: $SSD_DEVICE"
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
