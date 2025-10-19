#!/bin/bash

# ZimaBoard 2 SSD Storage Setup Script
# Comprehensive setup: formats, partitions, configures Proxmox storage pools, and optimizes 2TB SSD

set -e

echo "📀 ZimaBoard 2 SSD Storage Setup"
echo "================================="
echo "Comprehensive 2TB SSD setup with formatting, partitioning, and Proxmox integration..."
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

# Verify mounts are successful
if ! mountpoint -q /mnt/seafile-data; then
    echo "❌ Error: Failed to mount /mnt/seafile-data"
    exit 1
fi
if ! mountpoint -q /mnt/backup-storage; then
    echo "❌ Error: Failed to mount /mnt/backup-storage"
    exit 1
fi

# Set comprehensive permissions and ownership
echo "🔧 Setting up permissions and ownership..."
chmod 755 /mnt/seafile-data
chmod 755 /mnt/backup-storage
chown root:root /mnt/seafile-data /mnt/backup-storage

# Create subdirectories with proper permissions for services
mkdir -p /mnt/seafile-data/{containers,vms,logs}
mkdir -p /mnt/backup-storage/{proxmox-backups,container-backups,system-backups}
chmod 750 /mnt/seafile-data/{containers,vms,logs}
chmod 750 /mnt/backup-storage/{proxmox-backups,container-backups,system-backups}

# Configure Proxmox storage pools
echo "🔧 Configuring Proxmox storage pools..."
# Remove any existing storage configurations
pvesm remove seafile-storage 2>/dev/null || true
pvesm remove backup-storage 2>/dev/null || true

# Add primary storage pool for containers and VMs
pvesm add dir seafile-storage \
    --path /mnt/seafile-data \
    --content images,rootdir,backup,vztmpl \
    --maxfiles 10 \
    --shared 0

# Add backup storage pool
pvesm add dir backup-storage \
    --path /mnt/backup-storage \
    --content backup,vztmpl,iso \
    --maxfiles 5 \
    --shared 0

# Set SSD storage as default for new containers/VMs
echo "🔧 Setting SSD as default storage..."
# Update datacenter storage configuration to prioritize SSD
cat > /tmp/storage_priority.conf << 'EOF'
# Set SSD storage as default for new containers
storage: seafile-storage
	path /mnt/seafile-data
	content images,rootdir,backup,vztmpl
	maxfiles 10
	shared 0

storage: backup-storage
	path /mnt/backup-storage
	content backup,vztmpl,iso
	maxfiles 5
	shared 0
EOF

# Optimize SSD performance
echo "🔧 Optimizing SSD performance..."
# Set optimal I/O scheduler for SSD
if [[ -f /sys/block/$(basename $SSD_DEVICE)/queue/scheduler ]]; then
    echo 'mq-deadline' > /sys/block/$(basename $SSD_DEVICE)/queue/scheduler
    echo "Set I/O scheduler to mq-deadline for $SSD_DEVICE"
fi

# Enable TRIM support for SSD longevity
fstrim /mnt/seafile-data
fstrim /mnt/backup-storage
echo "Enabled TRIM for SSD partitions"

# Add weekly TRIM to crontab for maintenance
(crontab -l 2>/dev/null; echo "0 3 * * 0 /sbin/fstrim /mnt/seafile-data && /sbin/fstrim /mnt/backup-storage") | crontab -

# Create test files to verify write permissions
echo "🔧 Testing write permissions..."
echo "SSD storage test" > /mnt/seafile-data/test_write.txt
echo "Backup storage test" > /mnt/backup-storage/test_write.txt
rm -f /mnt/seafile-data/test_write.txt /mnt/backup-storage/test_write.txt
echo "✅ Write permissions verified"

echo ""
echo "✅ SSD Storage Setup Complete!"
echo "=============================="
echo "📊 Storage Configuration:"
echo "• Seafile NAS storage: /mnt/seafile-data (1TB)"
echo "  └─ Containers: /mnt/seafile-data/containers"
echo "  └─ VMs: /mnt/seafile-data/vms"
echo "  └─ Logs: /mnt/seafile-data/logs"
echo "• Backup storage: /mnt/backup-storage (1TB)"
echo "  └─ Proxmox backups: /mnt/backup-storage/proxmox-backups"
echo "  └─ Container backups: /mnt/backup-storage/container-backups"
echo "  └─ System backups: /mnt/backup-storage/system-backups"
echo ""
echo "🔧 Proxmox Storage Pools:"
pvesm status
echo ""
echo "💾 Current Usage:"
df -h /mnt/seafile-data /mnt/backup-storage
echo ""
echo "⚡ Performance Optimizations Applied:"
echo "• I/O Scheduler: mq-deadline (optimal for SSD)"
echo "• TRIM enabled for SSD longevity"
echo "• Weekly automated TRIM maintenance scheduled"
echo "• noatime mount option for reduced writes"
echo ""
echo "🎉 Ready for homelab deployment!"
echo "Next step: Run the complete setup script to deploy all services"
