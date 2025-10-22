#!/bin/bash
################################################################################
# ZimaBoard Homelab - Storage Setup Script
# 
# This script helps automate the detection, formatting, and mounting of storage
# drives for the homelab setup. It can:
# - Detect unformatted drives
# - Format drives with ext4
# - Create mount points
# - Add entries to /etc/fstab
# - Mount drives automatically
#
# CAUTION: This script can format drives and erase all data. Use with care!
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║     ZimaBoard Homelab - Storage Setup Script    ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Please use: sudo bash setup-storage.sh"
    exit 1
fi

warning "⚠️  WARNING: This script can format drives and ERASE ALL DATA!"
warning "    Make sure you have backups and verify device names carefully."
echo
read -p "Do you want to continue? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Setup cancelled by user"
    exit 0
fi
echo

################################################################################
# Step 1: Display current storage configuration
################################################################################

info "Step 1: Current storage configuration"
echo
echo "Block devices:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL
echo

info "Currently mounted filesystems:"
df -h | grep -E '^/dev|Filesystem'
echo

################################################################################
# Step 2: Identify drives to setup
################################################################################

info "Step 2: Identify drives for SSD and HDD"
echo

# List available block devices (excluding loop devices and partitions)
info "Available block devices (excluding eMMC):"
lsblk -d -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -v 'mmcblk' | grep -v 'loop'
echo

read -p "Enter the device name for your 2TB SSD (e.g., sda): " SSD_DEV
read -p "Enter the device name for your 500GB HDD (e.g., sdb): " HDD_DEV

# Validate device names
if [[ ! -b "/dev/$SSD_DEV" ]]; then
    error "Device /dev/$SSD_DEV does not exist"
    exit 1
fi

if [[ ! -b "/dev/$HDD_DEV" ]]; then
    error "Device /dev/$HDD_DEV does not exist"
    exit 1
fi

if [[ "$SSD_DEV" == "$HDD_DEV" ]]; then
    error "SSD and HDD devices must be different"
    exit 1
fi

echo
info "Selected devices:"
info "  SSD: /dev/$SSD_DEV"
info "  HDD: /dev/$HDD_DEV"
echo

# Show device information
info "Device information:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "/dev/$SSD_DEV"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "/dev/$HDD_DEV"
echo

warning "⚠️  FINAL WARNING: This will ERASE ALL DATA on these drives:"
warning "    /dev/$SSD_DEV"
warning "    /dev/$HDD_DEV"
echo
read -p "Type 'yes' to confirm and proceed: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    info "Setup cancelled by user"
    exit 0
fi
echo

################################################################################
# Step 3: Format drives
################################################################################

info "Step 3: Formatting drives..."
echo

# Unmount if already mounted
info "Unmounting devices if mounted..."
umount "/dev/${SSD_DEV}"* 2>/dev/null || true
umount "/dev/${HDD_DEV}"* 2>/dev/null || true
success "Devices unmounted"

# Format SSD
info "Formatting /dev/$SSD_DEV as ext4 with label 'SSD-Data'..."
parted /dev/$SSD_DEV --script mklabel gpt
parted /dev/$SSD_DEV --script mkpart primary ext4 0% 100%
sleep 2  # Wait for partition to be recognized
mkfs.ext4 -F /dev/${SSD_DEV}1 -L "SSD-Data"
success "SSD formatted successfully"
echo

# Format HDD
info "Formatting /dev/$HDD_DEV as ext4 with label 'HDD-Cache'..."
parted /dev/$HDD_DEV --script mklabel gpt
parted /dev/$HDD_DEV --script mkpart primary ext4 0% 100%
sleep 2  # Wait for partition to be recognized
mkfs.ext4 -F /dev/${HDD_DEV}1 -L "HDD-Cache"
success "HDD formatted successfully"
echo

################################################################################
# Step 4: Create mount points
################################################################################

info "Step 4: Creating mount points..."
echo

mkdir -p /mnt/ssd
mkdir -p /mnt/hdd
success "Mount points created: /mnt/ssd and /mnt/hdd"
echo

################################################################################
# Step 5: Get UUIDs and update /etc/fstab
################################################################################

info "Step 5: Configuring automatic mounting..."
echo

# Get UUIDs
SSD_UUID=$(blkid -s UUID -o value /dev/${SSD_DEV}1)
HDD_UUID=$(blkid -s UUID -o value /dev/${HDD_DEV}1)

info "Drive UUIDs:"
info "  SSD: $SSD_UUID"
info "  HDD: $HDD_UUID"
echo

# Backup fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
success "Created fstab backup"

# Check if entries already exist
if grep -q "$SSD_UUID" /etc/fstab; then
    warning "SSD entry already exists in /etc/fstab, skipping"
else
    info "Adding SSD to /etc/fstab..."
    echo "" >> /etc/fstab
    echo "# 2TB SSD for data storage (ZimaBoard Homelab)" >> /etc/fstab
    echo "UUID=$SSD_UUID  /mnt/ssd  ext4  defaults,nofail,commit=60  0  2" >> /etc/fstab
    success "SSD added to /etc/fstab"
fi

if grep -q "$HDD_UUID" /etc/fstab; then
    warning "HDD entry already exists in /etc/fstab, skipping"
else
    info "Adding HDD to /etc/fstab..."
    echo "# 500GB HDD for cache storage (ZimaBoard Homelab)" >> /etc/fstab
    echo "UUID=$HDD_UUID  /mnt/hdd  ext4  defaults,nofail,commit=60  0  2" >> /etc/fstab
    success "HDD added to /etc/fstab"
fi
echo

################################################################################
# Step 6: Mount drives
################################################################################

info "Step 6: Mounting drives..."
echo

mount -a

if mountpoint -q /mnt/ssd; then
    success "SSD mounted successfully at /mnt/ssd"
else
    error "Failed to mount SSD"
    exit 1
fi

if mountpoint -q /mnt/hdd; then
    success "HDD mounted successfully at /mnt/hdd"
else
    error "Failed to mount HDD"
    exit 1
fi
echo

# Display mount information
info "Mounted filesystems:"
df -h | grep -E '/mnt/(ssd|hdd)|Filesystem'
echo

################################################################################
# Step 7: Create service directories
################################################################################

info "Step 7: Creating service directories..."
echo

mkdir -p /mnt/ssd/fileshare
mkdir -p /mnt/hdd/lancache
mkdir -p /mnt/hdd/lancache-logs

success "Created service directories:"
info "  /mnt/ssd/fileshare (for Samba)"
info "  /mnt/hdd/lancache (for Lancache cache)"
info "  /mnt/hdd/lancache-logs (for Lancache logs)"
echo

################################################################################
# Step 8: Set permissions
################################################################################

info "Step 8: Setting permissions..."
echo

# Get the actual user who invoked sudo
ACTUAL_USER="${SUDO_USER:-$USER}"

chown -R $ACTUAL_USER:$ACTUAL_USER /mnt/ssd /mnt/hdd
chmod -R 777 /mnt/ssd/fileshare
chmod -R 777 /mnt/hdd/lancache
chmod -R 777 /mnt/hdd/lancache-logs

success "Permissions set (owner: $ACTUAL_USER, Samba/Lancache: 777)"
echo

################################################################################
# Step 9: Optional - Move Docker to SSD
################################################################################

info "Step 9: Optional - Move Docker data to SSD"
echo

if command -v docker &> /dev/null; then
    warning "Docker is installed. You can move Docker data to SSD to preserve eMMC."
    echo
    read -p "Do you want to move Docker data to SSD? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Moving Docker data to SSD..."
        
        # Stop Docker
        systemctl stop docker
        
        # Create Docker directory on SSD
        mkdir -p /mnt/ssd/docker
        
        # Copy existing Docker data if it exists
        if [[ -d /var/lib/docker ]]; then
            info "Copying existing Docker data (this may take a while)..."
            rsync -aP /var/lib/docker/ /mnt/ssd/docker/
            success "Docker data copied"
        fi
        
        # Update Docker daemon configuration
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "/mnt/ssd/docker"
}
EOF
        success "Docker daemon configuration updated"
        
        # Start Docker
        systemctl start docker
        
        # Verify
        DOCKER_ROOT=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $4}')
        if [[ "$DOCKER_ROOT" == "/mnt/ssd/docker" ]]; then
            success "Docker is now using: /mnt/ssd/docker"
            info "You can remove the old Docker data with: sudo rm -rf /var/lib/docker"
        else
            warning "Docker root directory verification failed. Please check manually."
        fi
    else
        info "Skipping Docker data move"
    fi
else
    info "Docker is not installed. Skipping this step."
fi
echo

################################################################################
# Summary
################################################################################

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║         Storage Setup Completed Successfully!   ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

success "Storage drives have been formatted and mounted:"
echo "  • SSD: /mnt/ssd (for file sharing and Docker)"
echo "  • HDD: /mnt/hdd (for Lancache)"
echo

success "Service directories have been created:"
echo "  • /mnt/ssd/fileshare"
echo "  • /mnt/hdd/lancache"
echo "  • /mnt/hdd/lancache-logs"
echo

info "Next steps:"
echo "  1. Configure your .env file: cp .env.example .env && nano .env"
echo "  2. Validate your environment: bash scripts/validate-env.sh"
echo "  3. Deploy services: docker compose up -d"
echo

info "Your /etc/fstab has been updated and backed up."
info "Drives will automatically mount on system boot."
echo
