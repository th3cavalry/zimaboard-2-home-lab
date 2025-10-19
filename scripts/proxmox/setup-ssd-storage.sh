#!/bin/bash

# SSD Storage Setup Script for ZimaBoard 2
# This script partitions and mounts the 2TB SSD for NAS and backup storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ZimaBoard 2 SSD Storage Setup ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Detect the SSD device
echo -e "${YELLOW}Detecting SSD device...${NC}"
SSD_DEVICE=""

# Common SSD device names
for device in /dev/sdb /dev/sdc /dev/sdd /dev/nvme0n1; do
    if [ -b "$device" ]; then
        # Get device size in GB
        SIZE=$(lsblk -b -n -o SIZE "$device" 2>/dev/null | head -n1)
        SIZE_GB=$((SIZE / 1024 / 1024 / 1024))
        
        echo -e "${BLUE}Found device: $device (${SIZE_GB}GB)${NC}"
        
        # Check if it's approximately 2TB (1800GB - 2200GB range)
        if [ "$SIZE_GB" -gt 1800 ] && [ "$SIZE_GB" -lt 2200 ]; then
            SSD_DEVICE="$device"
            echo -e "${GREEN}Using SSD device: $SSD_DEVICE (${SIZE_GB}GB)${NC}"
            break
        fi
    fi
done

if [ -z "$SSD_DEVICE" ]; then
    echo -e "${RED}No suitable 2TB SSD found!${NC}"
    echo -e "${YELLOW}Available devices:${NC}"
    lsblk
    exit 1
fi

# Show current partition table
echo -e "\n${YELLOW}Current partition table for $SSD_DEVICE:${NC}"
fdisk -l "$SSD_DEVICE" 2>/dev/null || echo "No partition table found"

# Warning
echo -e "\n${RED}WARNING: This will ERASE ALL DATA on $SSD_DEVICE!${NC}"
echo -e "${YELLOW}The drive will be partitioned as follows:${NC}"
echo -e "  Partition 1: 1TB for Nextcloud NAS storage"
echo -e "  Partition 2: ~1TB for backups and future expansion"
echo ""

read -p "Continue with partitioning? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Create partition table
echo -e "${YELLOW}Creating new partition table...${NC}"
parted "$SSD_DEVICE" --script mklabel gpt

# Create partitions
echo -e "${YELLOW}Creating partitions...${NC}"
parted "$SSD_DEVICE" --script mkpart primary ext4 0% 50%
parted "$SSD_DEVICE" --script mkpart primary ext4 50% 100%

# Set partition names
parted "$SSD_DEVICE" --script name 1 "nas-storage"
parted "$SSD_DEVICE" --script name 2 "backup-storage"

# Wait for kernel to update
sleep 2

# Determine partition naming
if [[ "$SSD_DEVICE" == *"nvme"* ]]; then
    PART1="${SSD_DEVICE}p1"
    PART2="${SSD_DEVICE}p2"
else
    PART1="${SSD_DEVICE}1"
    PART2="${SSD_DEVICE}2"
fi

# Format partitions
echo -e "${YELLOW}Formatting partitions...${NC}"
echo -e "Formatting $PART1 for NAS storage..."
mkfs.ext4 -F -L "nas-storage" "$PART1"

echo -e "Formatting $PART2 for backup storage..."
mkfs.ext4 -F -L "backup-storage" "$PART2"

# Create mount points
echo -e "${YELLOW}Creating mount points...${NC}"
mkdir -p /mnt/nas-storage
mkdir -p /mnt/backup-storage

# Mount partitions
echo -e "${YELLOW}Mounting partitions...${NC}"
mount "$PART1" /mnt/nas-storage
mount "$PART2" /mnt/backup-storage

# Get UUIDs for fstab
NAS_UUID=$(blkid -s UUID -o value "$PART1")
BACKUP_UUID=$(blkid -s UUID -o value "$PART2")

# Add to /etc/fstab
echo -e "${YELLOW}Adding entries to /etc/fstab...${NC}"
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

cat >> /etc/fstab << EOFSTAB

# ZimaBoard 2 SSD Storage
UUID=${NAS_UUID} /mnt/nas-storage ext4 defaults,noatime 0 2
UUID=${BACKUP_UUID} /mnt/backup-storage ext4 defaults,noatime 0 2
EOFSTAB

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown root:root /mnt/nas-storage /mnt/backup-storage
chmod 755 /mnt/nas-storage /mnt/backup-storage

# Create subdirectories
echo -e "${YELLOW}Creating subdirectories...${NC}"
mkdir -p /mnt/nas-storage/data
mkdir -p /mnt/nas-storage/config
mkdir -p /mnt/backup-storage/nextcloud
mkdir -p /mnt/backup-storage/proxmox
mkdir -p /mnt/backup-storage/snapshots

# Configure Proxmox storage
echo -e "${YELLOW}Configuring Proxmox storage...${NC}"
pvesm add dir nas-storage --path /mnt/nas-storage --content iso,vztmpl,backup,snippets
pvesm add dir backup-storage --path /mnt/backup-storage --content backup,snippets

# Create storage status script
cat > /usr/local/bin/storage-status << 'EOSCRIPT'
#!/bin/bash

echo "=== ZimaBoard 2 Storage Status ==="
echo "Date: $(date)"
echo ""

echo "=== Disk Usage ==="
df -h /mnt/nas-storage /mnt/backup-storage

echo ""
echo "=== Mount Points ==="
mount | grep -E "(nas-storage|backup-storage)"

echo ""
echo "=== Storage Information ==="
lsblk -f | grep -E "(nas-storage|backup-storage)"

echo ""
echo "=== Proxmox Storage Status ==="
pvesm status || echo "Run from Proxmox node to see storage status"
EOSCRIPT

chmod +x /usr/local/bin/storage-status

# Display setup summary
echo -e "\n${GREEN}=== Storage Setup Complete! ===${NC}"
echo -e "${BLUE}SSD Device:${NC} $SSD_DEVICE"
echo -e "${BLUE}NAS Partition:${NC} $PART1 (UUID: ${NAS_UUID})"
echo -e "${BLUE}Backup Partition:${NC} $PART2 (UUID: ${BACKUP_UUID})"
echo -e ""
echo -e "${BLUE}Mount Points:${NC}"
echo -e "  /mnt/nas-storage - 1TB for Nextcloud NAS"
echo -e "  /mnt/backup-storage - 1TB for backups"
echo -e ""
echo -e "${BLUE}Storage Usage:${NC}"
df -h /mnt/nas-storage /mnt/backup-storage
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Run Proxmox deployment script to create VMs"
echo -e "2. Install Nextcloud on VM 300"
echo -e "3. Configure Nextcloud to use /mnt/nas-storage/data"
echo -e "4. Set up automated backups to /mnt/backup-storage"
echo -e ""
echo -e "${GREEN}Run 'storage-status' to check storage health${NC}"
