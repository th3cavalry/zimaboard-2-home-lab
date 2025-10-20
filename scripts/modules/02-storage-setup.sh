#!/bin/bash
################################################################################
# Storage Setup Module
# Part of ZimaBoard 2 Homelab Installation System
################################################################################

setup_storage() {
    print_info "💾 Configuring optimal storage for ZimaBoard 2..."
    
    # Check for SSD availability
    print_info "🔍 Detecting available storage devices..."
    
    DETECTED_SSDS=()
    for device in /dev/sd? /dev/nvme?n?; do
        if [[ -b "$device" ]]; then
            SIZE=$(lsblk -b -d -o SIZE "$device" 2>/dev/null | tail -n1)
            # Look for devices larger than 500GB
            if [[ "$SIZE" -gt 500000000000 ]]; then
                DEVICE_INFO=$(lsblk -d -o NAME,SIZE,MODEL "$device" 2>/dev/null | tail -n1)
                DETECTED_SSDS+=("$device:$DEVICE_INFO")
            fi
        fi
    done
    
    if [[ ${#DETECTED_SSDS[@]} -eq 0 ]]; then
        print_warning "No large storage devices detected"
        print_info "Using eMMC-only configuration"
        setup_emmc_only
        return 0
    fi
    
    print_success "Found ${#DETECTED_SSDS[@]} potential SSD(s)"
    for i in "${!DETECTED_SSDS[@]}"; do
        IFS=':' read -r device info <<< "${DETECTED_SSDS[$i]}"
        echo "  $((i+1)). $info"
    done
    
    echo ""
    print_info "SSD Setup Options:"
    echo "1) 🚀 Auto-configure (recommended - uses first detected SSD)"
    echo "2) ⚙️ Interactive setup (choose SSD and partitioning)"
    echo "3) ⏭️ Skip SSD (eMMC only)"
    
    read -p "Select option (1-3): " choice
    case $choice in
        1) setup_auto_ssd ;;
        2) setup_interactive_ssd ;;
        3) setup_emmc_only ;;
        *) 
            print_warning "Invalid choice, using auto-configure"
            setup_auto_ssd
            ;;
    esac
    
    return 0
}

setup_emmc_only() {
    print_info "📱 Configuring eMMC-only storage..."
    
    export DATA_DIR="/opt/homelab-data"
    export SSD_AVAILABLE=false
    
    mkdir -p "$DATA_DIR"/{adguardhome,nextcloud,squid-cache,backups,logs}
    chmod 755 "$DATA_DIR"
    
    print_success "✅ eMMC storage configured"
    print_info "   Data directory: $DATA_DIR"
    print_warning "   Note: Consider adding SSD for better performance"
}

setup_auto_ssd() {
    print_info "🚀 Auto-configuring SSD storage..."
    
    # Use first detected SSD
    IFS=':' read -r SSD_DEVICE info <<< "${DETECTED_SSDS[0]}"
    
    print_info "Using SSD: $info"
    print_warning "⚠️ This will create new partitions (existing data preserved if possible)"
    
    read -p "Continue with auto-setup? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Switching to eMMC-only mode"
        setup_emmc_only
        return 0
    fi
    
    configure_ssd_storage "$SSD_DEVICE"
}

setup_interactive_ssd() {
    print_info "⚙️ Interactive SSD setup..."
    
    # Let user choose SSD
    if [[ ${#DETECTED_SSDS[@]} -eq 1 ]]; then
        IFS=':' read -r SSD_DEVICE info <<< "${DETECTED_SSDS[0]}"
    else
        echo ""
        print_info "Select SSD to configure:"
        for i in "${!DETECTED_SSDS[@]}"; do
            IFS=':' read -r device info <<< "${DETECTED_SSDS[$i]}"
            echo "  $((i+1)). $info"
        done
        
        read -p "Select SSD (1-${#DETECTED_SSDS[@]}): " ssd_choice
        if [[ "$ssd_choice" =~ ^[1-9][0-9]*$ ]] && [[ "$ssd_choice" -le ${#DETECTED_SSDS[@]} ]]; then
            IFS=':' read -r SSD_DEVICE info <<< "${DETECTED_SSDS[$((ssd_choice-1))]}"
        else
            print_error "Invalid selection"
            setup_emmc_only
            return 1
        fi
    fi
    
    configure_ssd_storage "$SSD_DEVICE"
}

configure_ssd_storage() {
    local SSD_DEVICE=$1
    
    print_info "💽 Configuring SSD: $SSD_DEVICE"
    
    # Install partitioning tools
    apt install -y parted
    
    # Check for existing partitions
    EXISTING_PARTS=$(lsblk -p -n -o NAME "$SSD_DEVICE" | grep -v "^$SSD_DEVICE$" | head -5)
    
    if [[ -n "$EXISTING_PARTS" ]]; then
        print_info "Found existing partitions:"
        lsblk "$SSD_DEVICE"
        echo ""
        
        # Try to use existing partition
        FIRST_PART=$(echo "$EXISTING_PARTS" | head -1 | tr -d ' ')
        if [[ -n "$FIRST_PART" ]]; then
            print_info "Attempting to use existing partition: $FIRST_PART"
            
            # Create mount point and test
            mkdir -p /mnt/ssd-data
            if mount "$FIRST_PART" /mnt/ssd-data 2>/dev/null; then
                print_success "Using existing partition successfully"
                
                # Add to fstab if not already present
                SSD_UUID=$(blkid -s UUID -o value "$FIRST_PART")
                if ! grep -q "$SSD_UUID" /etc/fstab 2>/dev/null; then
                    echo "UUID=$SSD_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
                fi
                
                export DATA_DIR="/mnt/ssd-data"
                export SSD_AVAILABLE=true
                
                setup_ssd_directories
                return 0
            else
                print_warning "Could not mount existing partition, creating new layout"
            fi
        fi
    fi
    
    # Create new partition layout
    print_info "Creating new partition layout..."
    
    # Unmount any existing partitions
    for part in ${SSD_DEVICE}*; do
        if [[ -b "$part" ]] && [[ "$part" != "$SSD_DEVICE" ]]; then
            umount "$part" 2>/dev/null || true
        fi
    done
    
    # Create GPT partition table and single large partition
    parted -s "$SSD_DEVICE" mklabel gpt
    parted -s "$SSD_DEVICE" mkpart primary ext4 0% 100%
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$SSD_DEVICE" 2>/dev/null || true
    sleep 1
    
    # Determine partition name
    if [[ "$SSD_DEVICE" =~ nvme ]]; then
        DATA_PARTITION="${SSD_DEVICE}p1"
    else
        DATA_PARTITION="${SSD_DEVICE}1"
    fi
    
    # Format partition
    print_info "Formatting partition with ext4..."
    mkfs.ext4 -F "$DATA_PARTITION" -L "homelab-data"
    
    # Mount and configure
    mkdir -p /mnt/ssd-data
    mount "$DATA_PARTITION" /mnt/ssd-data
    
    # Add to fstab
    SSD_UUID=$(blkid -s UUID -o value "$DATA_PARTITION")
    echo "UUID=$SSD_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" >> /etc/fstab
    
    export DATA_DIR="/mnt/ssd-data"
    export SSD_AVAILABLE=true
    
    setup_ssd_directories
    
    print_success "✅ SSD storage configured successfully"
    print_info "   Device: $SSD_DEVICE"
    print_info "   Partition: $DATA_PARTITION"
    print_info "   Mount: /mnt/ssd-data"
    print_info "   Filesystem: ext4 with noatime"
}

setup_ssd_directories() {
    print_info "�� Setting up service directories on SSD..."
    
    # Create service directories
    mkdir -p "$DATA_DIR"/{adguardhome,nextcloud,squid-cache,backups,logs}
    chmod 755 "$DATA_DIR"
    
    # Move logs to SSD to reduce eMMC writes
    if [[ ! -L /var/log ]] && [[ -d "$DATA_DIR" ]]; then
        print_info "Moving system logs to SSD for eMMC longevity..."
        
        # Copy existing logs
        cp -a /var/log/* "$DATA_DIR/logs/" 2>/dev/null || true
        
        # Backup original and create symlink
        mv /var/log /var/log.original
        ln -s "$DATA_DIR/logs" /var/log
        
        print_success "System logs redirected to SSD"
    fi
    
    print_success "✅ SSD directories configured"
    print_info "   AdGuard Home data: $DATA_DIR/adguardhome"
    print_info "   Nextcloud data: $DATA_DIR/nextcloud" 
    print_info "   Squid cache: $DATA_DIR/squid-cache"
    print_info "   System logs: $DATA_DIR/logs"
    print_info "   Backups: $DATA_DIR/backups"
}

# Export functions for use by main installer
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f setup_storage setup_emmc_only setup_auto_ssd setup_interactive_ssd configure_ssd_storage setup_ssd_directories
fi
