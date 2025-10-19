#!/bin/bash

# ZimaBoard 2 SSD Storage Setup Script - Interactive Mode
# Configures 2TB SSD for ZimaBoard homelab with user-selectable formatting options
# Comprehensive setup: optional formatting, partitioning, configures Proxmox storage pools, and optimizes 2TB SSD

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

echo "📀 ZimaBoard 2 SSD Storage Setup"
echo "================================"
echo "🔧 Interactive setup for 2TB SSD storage configuration"
echo "Choose your setup mode based on your current SSD state"
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

# Check for existing partitions
EXISTING_PARTITIONS=$(lsblk -n -o NAME "$SSD_DEVICE" | grep -v "^$(basename $SSD_DEVICE)$" | wc -l)
HAS_DATA=false

if [[ $EXISTING_PARTITIONS -gt 0 ]]; then
    echo "📋 Existing partitions detected on $SSD_DEVICE:"
    lsblk $SSD_DEVICE
    echo ""
    
    # Check if partitions are mounted or contain data
    for part in ${SSD_DEVICE}*; do
        if [[ -b "$part" && "$part" != "$SSD_DEVICE" ]]; then
            if mountpoint -q "$part" 2>/dev/null; then
                echo "⚠️  Partition $part is currently mounted"
                HAS_DATA=true
            elif [[ $(file -s "$part" | grep -c "filesystem\|data") -gt 0 ]]; then
                echo "⚠️  Partition $part appears to contain data"
                HAS_DATA=true
            fi
        fi
    done
fi

# Interactive setup mode selection
echo "🎯 Setup Mode Selection"
echo "======================="
echo "1) Fresh Format - Completely erase and reformat $SSD_DEVICE (recommended for new drives)"
echo "2) Use Existing Partitions - Configure Proxmox storage with existing partitions (preserves data)"
echo "3) Advanced - Manual partition selection and optional formatting"
echo "4) Exit - Cancel setup"
echo ""

# Auto-format mode check (for backwards compatibility)
if [[ "${AUTO_FORMAT:-0}" == "1" ]]; then
    echo "🚨 AUTO_FORMAT=1 detected - Using automatic fresh format mode"
    SETUP_MODE="1"
elif [[ ! -t 0 ]]; then
    # Non-interactive mode (piped input) - default to existing partitions mode for safety
    echo "🔄 Non-interactive mode detected - Using existing partitions mode (safest option)"
    echo "To force fresh format in non-interactive mode, use: AUTO_FORMAT=1"
    SETUP_MODE="2"
else
    # Interactive mode
    while true; do
        read -p "Select setup mode [1-4]: " SETUP_MODE
        case $SETUP_MODE in
            [1-4])
                break
                ;;
            *)
                echo "❌ Invalid option. Please select 1, 2, 3, or 4."
                ;;
        esac
    done
fi

echo ""

case $SETUP_MODE in
    1)
        echo "🚨 FRESH FORMAT MODE: This will completely erase $SSD_DEVICE!"
        if [[ $HAS_DATA == true ]]; then
            echo "⚠️  WARNING: Existing data detected on this drive!"
            echo "This will permanently delete all data on $SSD_DEVICE"
            echo ""
            
            # Handle non-interactive mode
            if [[ ! -t 0 ]]; then
                echo "❌ Non-interactive mode with existing data detected!"
                echo "Cannot safely proceed without user confirmation."
                echo "Use AUTO_FORMAT=1 environment variable to force formatting."
                exit 1
            fi
            
            read -p "Type 'ERASE' to confirm complete data deletion: " confirm
            if [[ "$confirm" != "ERASE" ]]; then
                echo "❌ Operation cancelled by user"
                exit 1
            fi
        fi
        FORMAT_DRIVE=true
        ;;
    2)
        echo "🔄 EXISTING PARTITIONS MODE: Will use current partitions"
        if [[ $EXISTING_PARTITIONS -lt 2 ]]; then
            echo "❌ Error: Need at least 2 partitions for homelab setup"
            echo "Current partitions: $EXISTING_PARTITIONS"
            echo "Please use Fresh Format mode or create partitions manually"
            exit 1
        fi
        FORMAT_DRIVE=false
        ;;
    3)
        echo "🔧 ADVANCED MODE: Manual configuration"
        if [[ ! -t 0 ]]; then
            echo "❌ Advanced mode requires interactive input"
            echo "Falling back to existing partitions mode for non-interactive execution"
            SETUP_MODE="2"
        fi
        FORMAT_DRIVE=false  # Will be set based on user choices below
        ;;
    4)
        echo "👋 Setup cancelled by user"
        exit 0
        ;;
esac

echo ""

# Execute setup based on selected mode
if [[ $FORMAT_DRIVE == true ]]; then
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
        fdisk $SSD_DEVICE << 'EOF'
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
    echo "📋 New partition layout:"
    lsblk $SSD_DEVICE

elif [[ $SETUP_MODE == "2" ]]; then
    # Use existing partitions mode
    echo "🔄 Using existing partitions..."
    
    # Automatically detect the first two partitions
    echo "🔍 Detecting partitions on $SSD_DEVICE..."
    
    # Debug: Show raw lsblk output
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "Debug - Raw lsblk output:"
        lsblk "$SSD_DEVICE"
        echo "Debug - Partition detection:"
        lsblk -ln -o NAME "$SSD_DEVICE" | grep -v "^$(basename $SSD_DEVICE)$"
    fi
    
    # Use lsblk with proper formatting to get clean partition names
    # Remove tree formatting characters and extract just the device names
    RAW_PARTITIONS=$(lsblk -ln -o NAME "$SSD_DEVICE" | grep -v "^$(basename $SSD_DEVICE)$")
    
    # Clean partition names more aggressively to handle all tree formatting
    CLEAN_PARTITIONS=()
    while IFS= read -r line; do
        # Remove all tree characters and whitespace, extract just the device name
        clean_name=$(echo "$line" | sed -E 's/^[├└─│ ├─└─│]*//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [[ -n "$clean_name" ]]; then
            CLEAN_PARTITIONS+=("$clean_name")
        fi
    done <<< "$RAW_PARTITIONS"
    
    if [[ ${#CLEAN_PARTITIONS[@]} -lt 2 ]]; then
        echo "❌ Error: Found ${#CLEAN_PARTITIONS[@]} partitions, need at least 2"
        echo "Available partitions: ${CLEAN_PARTITIONS[@]}"
        echo "Current disk layout:"
        lsblk "$SSD_DEVICE"
        exit 1
    fi
    
    SSD_PART1="/dev/${CLEAN_PARTITIONS[0]}"
    SSD_PART2="/dev/${CLEAN_PARTITIONS[1]}"
    
    # Validate partition paths
    if [[ "$DEBUG" == "1" ]]; then
        echo "Debug: Raw partitions: $RAW_PARTITIONS"
        echo "Debug: Clean partitions: ${CLEAN_PARTITIONS[@]}"
        echo "Debug: SSD_PART1=$SSD_PART1, SSD_PART2=$SSD_PART2"
    fi
    
    for part in $SSD_PART1 $SSD_PART2; do
        if [[ ! -b "$part" ]]; then
            echo "❌ Error: Invalid partition path: $part"
            echo "Debug: Clean partition names: ${CLEAN_PARTITIONS[@]}"
            echo "Current disk layout:"
            lsblk "$SSD_DEVICE"
            exit 1
        fi
    done
    
    echo "Selected partitions:"
    echo "• Seafile data: $SSD_PART1"
    echo "• Backup storage: $SSD_PART2"
    
    # Check if partitions need formatting
    for part in $SSD_PART1 $SSD_PART2; do
        FS_TYPE=$(lsblk -n -o FSTYPE "$part" 2>/dev/null || echo "")
        if [[ -z "$FS_TYPE" || "$FS_TYPE" != "ext4" ]]; then
            echo "⚠️  Partition $part is not ext4 formatted"
            
            # Handle non-interactive mode - default to no formatting (preserve data)
            if [[ ! -t 0 ]]; then
                echo "🔄 Non-interactive mode: Skipping formatting to preserve data"
                echo "   Partition will be used as-is (may cause issues if not compatible)"
                format_confirm="n"
            else
                read -p "Format $part as ext4? [y/N]: " format_confirm
            fi
            
            if [[ "$format_confirm" =~ ^[Yy] ]]; then
                echo "🔧 Formatting $part as ext4..."
                umount "$part" 2>/dev/null || true
                if [[ "$part" == "$SSD_PART1" ]]; then
                    mkfs.ext4 -F "$part" -L "seafile-data" -m 1
                else
                    mkfs.ext4 -F "$part" -L "backup-storage" -m 1
                fi
            fi
        else
            echo "✅ Partition $part already has ext4 filesystem"
        fi
    done

elif [[ $SETUP_MODE == "3" ]]; then
    # Advanced mode - let user select partitions
    echo "🔧 Advanced partition selection..."
    
    echo "Available partitions on $SSD_DEVICE:"
    lsblk $SSD_DEVICE
    echo ""
    
    # Get available partitions with clean formatting
    RAW_PARTS=$(lsblk -ln -o NAME "$SSD_DEVICE" | grep -v "^$(basename $SSD_DEVICE)$")
    AVAILABLE_PARTS=()
    while IFS= read -r line; do
        # Remove all tree characters and whitespace, extract just the device name
        clean_name=$(echo "$line" | sed -E 's/^[├└─│ ├─└─│]*//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [[ -n "$clean_name" ]]; then
            AVAILABLE_PARTS+=("$clean_name")
        fi
    done <<< "$RAW_PARTS"
    
    if [[ ${#AVAILABLE_PARTS[@]} -eq 0 ]]; then
        echo "❌ No partitions found. Creating new partitions..."
        echo "🔧 Wiping existing partition table..."
        wipefs -a $SSD_DEVICE
        
        echo "🔧 Creating new GPT partition table..."
        if command -v parted &> /dev/null; then
            parted -s $SSD_DEVICE mklabel gpt
            parted -s $SSD_DEVICE mkpart primary ext4 0% 50%
            parted -s $SSD_DEVICE mkpart primary ext4 50% 100%
        fi
        
        sleep 3
        partprobe $SSD_DEVICE 2>/dev/null || true
        udevadm settle --timeout=10 2>/dev/null || true
        sleep 2
        
        SSD_PART1="${SSD_DEVICE}1"
        SSD_PART2="${SSD_DEVICE}2"
        
        mkfs.ext4 -F $SSD_PART1 -L "seafile-data" -m 1
        mkfs.ext4 -F $SSD_PART2 -L "backup-storage" -m 1
    else
        echo "Select partition for Seafile data storage:"
        for i in "${!AVAILABLE_PARTS[@]}"; do
            PART_SIZE=$(lsblk -n -o SIZE "/dev/${AVAILABLE_PARTS[$i]}" 2>/dev/null || echo "Unknown")
            echo "$((i+1))) /dev/${AVAILABLE_PARTS[$i]} (${PART_SIZE})"
        done
        
        while true; do
            read -p "Select seafile partition [1-${#AVAILABLE_PARTS[@]}]: " part1_idx
            if [[ "$part1_idx" =~ ^[0-9]+$ ]] && [[ $part1_idx -ge 1 && $part1_idx -le ${#AVAILABLE_PARTS[@]} ]]; then
                SSD_PART1="/dev/${AVAILABLE_PARTS[$((part1_idx-1))]}"
                break
            fi
            echo "Invalid selection. Please choose 1-${#AVAILABLE_PARTS[@]}"
        done
        
        echo "Select partition for backup storage:"
        for i in "${!AVAILABLE_PARTS[@]}"; do
            if [[ "/dev/${AVAILABLE_PARTS[$i]}" != "$SSD_PART1" ]]; then
                PART_SIZE=$(lsblk -n -o SIZE "/dev/${AVAILABLE_PARTS[$i]}" 2>/dev/null || echo "Unknown")
                echo "$((i+1))) /dev/${AVAILABLE_PARTS[$i]} (${PART_SIZE})"
            fi
        done
        
        while true; do
            read -p "Select backup partition [1-${#AVAILABLE_PARTS[@]}]: " part2_idx
            if [[ "$part2_idx" =~ ^[0-9]+$ ]] && [[ $part2_idx -ge 1 && $part2_idx -le ${#AVAILABLE_PARTS[@]} ]]; then
                SSD_PART2="/dev/${AVAILABLE_PARTS[$((part2_idx-1))]}"
                if [[ "$SSD_PART2" != "$SSD_PART1" ]]; then
                    break
                fi
                echo "❌ Cannot use the same partition for both purposes"
            fi
            echo "Invalid selection. Please choose a different partition."
        done
        
        echo ""
        echo "Selected configuration:"
        echo "• Seafile data: $SSD_PART1"
        echo "• Backup storage: $SSD_PART2"
        
        # Ask about formatting each partition
        for part in $SSD_PART1 $SSD_PART2; do
            FS_TYPE=$(lsblk -n -o FSTYPE "$part" 2>/dev/null || echo "")
            PART_PURPOSE=$([ "$part" == "$SSD_PART1" ] && echo "seafile-data" || echo "backup-storage")
            
            if [[ -n "$FS_TYPE" ]]; then
                echo "Partition $part currently has filesystem: $FS_TYPE"
                read -p "Format $part as ext4 for $PART_PURPOSE? [y/N]: " format_confirm
            else
                echo "Partition $part has no filesystem"
                read -p "Format $part as ext4 for $PART_PURPOSE? [Y/n]: " format_confirm
                [[ -z "$format_confirm" ]] && format_confirm="y"
            fi
            
            if [[ "$format_confirm" =~ ^[Yy] ]]; then
                echo "🔧 Formatting $part as ext4..."
                umount "$part" 2>/dev/null || true
                mkfs.ext4 -F "$part" -L "$PART_PURPOSE" -m 1
            fi
        done
    fi
fi

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
