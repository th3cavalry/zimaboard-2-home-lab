#!/bin/bash

# ZimaBoard 2 SSD Format & Partition Script
# Format and partition 2TB SSD only (no Proxmox configuration)

set -e

echo "💾 ZimaBoard 2 SSD Format & Partition"
echo "====================================="
echo "Format and partition 2TB SSD for manual configuration..."
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

# Show what will be created
echo "📋 Partition Plan:"
echo "• Partition 1: /dev/${SSD_DEVICE##*/}1 (1TB) - Primary storage"
echo "• Partition 2: /dev/${SSD_DEVICE##*/}2 (1TB) - Backup storage"
echo ""

# Confirm before proceeding
read -p "⚠️  This will ERASE all data on $SSD_DEVICE. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted by user"
    exit 1
fi

# Unmount any existing partitions
echo "🔧 Unmounting any existing partitions..."
umount ${SSD_DEVICE}* 2>/dev/null || echo "No partitions were mounted"

echo "🔧 Creating GPT partition table..."
# Create GPT partition table
parted -s $SSD_DEVICE mklabel gpt

# Create partitions:
# 1TB for primary storage
# 1TB for backup storage
echo "🔧 Creating partitions..."
parted -s $SSD_DEVICE mkpart primary ext4 0% 50%
parted -s $SSD_DEVICE mkpart primary ext4 50% 100%

# Wait for system to recognize new partitions
echo "�� Waiting for partition table updates..."
sleep 3
partprobe $SSD_DEVICE

# Format partitions
echo "�� Formatting partitions with ext4..."
mkfs.ext4 -F ${SSD_DEVICE}1 -L "primary-storage"
mkfs.ext4 -F ${SSD_DEVICE}2 -L "backup-storage"

# Create basic mount points
echo "🔧 Creating mount points..."
mkdir -p /mnt/primary-storage
mkdir -p /mnt/backup-storage

# Get UUIDs for reference
PRIMARY_UUID=$(blkid -s UUID -o value ${SSD_DEVICE}1)
BACKUP_UUID=$(blkid -s UUID -o value ${SSD_DEVICE}2)

echo ""
echo "✅ SSD Format & Partition Complete!"
echo "===================================="
echo "📊 Created Partitions:"
echo "• ${SSD_DEVICE}1 (1TB) - Label: primary-storage"
echo "  └─ UUID: $PRIMARY_UUID"
echo "• ${SSD_DEVICE}2 (1TB) - Label: backup-storage"
echo "  └─ UUID: $BACKUP_UUID"
echo ""
echo "💾 Current Partition Layout:"
lsblk $SSD_DEVICE
echo ""
echo "📋 To manually mount partitions:"
echo "mount ${SSD_DEVICE}1 /mnt/primary-storage"
echo "mount ${SSD_DEVICE}2 /mnt/backup-storage"
echo ""
echo "📋 To add to /etc/fstab for permanent mounting:"
echo "UUID=$PRIMARY_UUID /mnt/primary-storage ext4 defaults,noatime 0 2"
echo "UUID=$BACKUP_UUID /mnt/backup-storage ext4 defaults,noatime 0 2"
echo ""
echo "🚀 Ready for manual configuration!"
