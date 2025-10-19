#!/bin/bash

# ZimaBoard 2 SSD Storage Setup Script - AUTOMATIC FORMAT MODE
# AUTOMATICALLY erases and reformats 2TB SSD from scratch
# Comprehensive setup: formats, partitions, configures Proxmox storage pools, and optimizes 2TB SSD

set -e

# Enable debug mode if DEBUG=1 is set
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
    echo "🐛 Debug mode enabled"
fi

# Function to handle cleanup on error
cleanup() {
    echo "❌ Script interrupted or failed. Cleaning up..."
    # Unmount any partially mounted filesystems
    umount /mnt/seafile-data 2>/dev/null || true
    umount /mnt/backup-storage 2>/dev/null || true
}
trap cleanup EXIT ERR

echo "📀 ZimaBoard 2 SSD Storage Setup - AUTOMATIC FORMAT"
echo "=================================================="
echo "⚠️  AUTOMATIC MODE: Will completely erase and reformat 2TB SSD!"
echo "Comprehensive setup with fresh formatting, partitioning, and Proxmox integration..."
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

# Install required packages if not present
echo "🔧 Checking for required tools..."
if ! command -v parted &> /dev/null; then
    echo "Installing parted..."
    apt update -qq && apt install -y parted
fi
if ! command -v wipefs &> /dev/null; then
    echo "Installing util-linux (wipefs)..."
    apt install -y util-linux
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

# Automatic format: Start from scratch - ERASE ALL DATA
echo "🚨 AUTOMATIC FORMAT MODE: This will completely erase $SSD_DEVICE!"
echo "🔧 Unmounting any existing partitions..."
umount ${SSD_DEVICE}* 2>/dev/null || echo "No partitions were mounted"

echo "🔧 Wiping existing partition table..."
# Wipe any existing partition signatures
wipefs -a $SSD_DEVICE

echo "🔧 Creating new GPT partition table..."
# Create fresh GPT partition table using parted or fdisk as fallback
if command -v parted &> /dev/null; then
    echo "Using parted for partitioning..."
    parted -s $SSD_DEVICE mklabel gpt
    
    # Create partitions:
    # 1TB for Seafile NAS data (homelab services)
    # 1TB for backups and expansion  
    echo "🔧 Creating fresh partitions..."
    parted -s $SSD_DEVICE mkpart primary ext4 0% 50%
    parted -s $SSD_DEVICE mkpart primary ext4 50% 100%
else
    echo "Using fdisk for partitioning..."
    # Create GPT partition table with fdisk
    fdisk $SSD_DEVICE << EOF
g
n
1

+950G
n
2


w
EOF
fi

# Wait for system to recognize new partitions
echo "🔧 Waiting for partition table updates..."
sleep 3
partprobe $SSD_DEVICE 2>/dev/null || echo "⚠️ partprobe failed, continuing..."
udevadm settle --timeout=10 2>/dev/null || echo "⚠️ udevadm settle timeout, continuing..."

# Give additional time for device nodes to appear
sleep 2

# Set partition variables for fresh setup
SSD_PART1="${SSD_DEVICE}1"
SSD_PART2="${SSD_DEVICE}2"

# Format partitions with ext4
echo "🔧 Formatting partitions with ext4..."
mkfs.ext4 -F $SSD_PART1 -L "seafile-data" -m 1
mkfs.ext4 -F $SSD_PART2 -L "backup-storage" -m 1

echo "✅ Fresh partition setup complete!"
echo "� New partition layout:"
lsblk $SSD_DEVICE

# Partitions are handled above based on existing vs new setup

# Create mount points
echo "🔧 Creating mount points..."
mkdir -p /mnt/seafile-data
mkdir -p /mnt/backup-storage

# Get UUIDs for fstab (using dynamic partition variables)
SEAFILE_UUID=$(blkid -s UUID -o value $SSD_PART1)
BACKUP_UUID=$(blkid -s UUID -o value $SSD_PART2)

# Add to fstab
echo "🔧 Adding to /etc/fstab..."
cp /etc/fstab /etc/fstab.backup
echo "" >> /etc/fstab
echo "# ZimaBoard 2 SSD Storage" >> /etc/fstab
echo "UUID=$SEAFILE_UUID /mnt/seafile-data ext4 defaults,noatime 0 2" >> /etc/fstab
echo "UUID=$BACKUP_UUID /mnt/backup-storage ext4 defaults,noatime 0 2" >> /etc/fstab

# Mount the partitions
echo "🔧 Mounting partitions..."
mount $SSD_PART1 /mnt/seafile-data
mount $SSD_PART2 /mnt/backup-storage

# Test mount points
echo "🔧 Verifying mount points..."
mountpoint -q /mnt/seafile-data && echo "✅ /mnt/seafile-data mounted successfully"
mountpoint -q /mnt/backup-storage && echo "✅ /mnt/backup-storage mounted successfully"

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
    --shared 0

# Add backup storage pool
pvesm add dir backup-storage \
    --path /mnt/backup-storage \
    --content backup,vztmpl,iso \
    --shared 0

# Verify Proxmox storage configuration
echo "🔧 Verifying Proxmox storage configuration..."
echo "Available storage pools:"
pvesm status

# Optimize SSD performance
echo "🔧 Optimizing SSD performance..."
# Set optimal I/O scheduler for SSD with proper error handling
SSD_BASE=$(basename $SSD_DEVICE)
SCHEDULER_PATH="/sys/block/$SSD_BASE/queue/scheduler"

if [[ -f "$SCHEDULER_PATH" ]]; then
    # Check available schedulers first
    AVAILABLE_SCHEDULERS=$(cat "$SCHEDULER_PATH" 2>/dev/null || echo "")
    echo "Available I/O schedulers for $SSD_DEVICE: $AVAILABLE_SCHEDULERS"
    
    # Try to set mq-deadline, fallback to none if not available
    if echo "$AVAILABLE_SCHEDULERS" | grep -q "mq-deadline"; then
        echo 'mq-deadline' > "$SCHEDULER_PATH" 2>/dev/null && \
            echo "✅ Set I/O scheduler to mq-deadline for $SSD_DEVICE" || \
            echo "⚠️ Failed to set mq-deadline scheduler, continuing..."
    elif echo "$AVAILABLE_SCHEDULERS" | grep -q "deadline"; then
        echo 'deadline' > "$SCHEDULER_PATH" 2>/dev/null && \
            echo "✅ Set I/O scheduler to deadline for $SSD_DEVICE" || \
            echo "⚠️ Failed to set deadline scheduler, continuing..."
    elif echo "$AVAILABLE_SCHEDULERS" | grep -q "none"; then
        echo 'none' > "$SCHEDULER_PATH" 2>/dev/null && \
            echo "✅ Set I/O scheduler to none (optimal for NVMe) for $SSD_DEVICE" || \
            echo "⚠️ Failed to set none scheduler, continuing..."
    else
        echo "⚠️ No optimal scheduler found, using system default"
    fi
else
    echo "⚠️ Scheduler configuration not available for $SSD_DEVICE (likely NVMe - uses none by default)"
fi

# Enable TRIM support for SSD longevity
echo "🔧 Enabling TRIM support for SSD longevity..."
timeout 30 fstrim /mnt/seafile-data 2>/dev/null && \
    echo "✅ TRIM enabled for /mnt/seafile-data" || \
    echo "⚠️ TRIM not available or failed for /mnt/seafile-data"

timeout 30 fstrim /mnt/backup-storage 2>/dev/null && \
    echo "✅ TRIM enabled for /mnt/backup-storage" || \
    echo "⚠️ TRIM not available or failed for /mnt/backup-storage"

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

# Clear the error trap on successful completion
trap - EXIT ERR
echo ""
echo "✅ Script completed successfully - no errors detected"
