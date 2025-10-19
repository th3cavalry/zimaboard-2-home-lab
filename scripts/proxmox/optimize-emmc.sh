#!/bin/bash

# eMMC Optimization Script for Proxmox VE
# Optimizes eMMC storage for longevity and performance
# Based on best practices from Debian Wiki and ArchLinux documentation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/emmc-optimization.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log "❌ Error: This script must be run as root"
   exit 1
fi

log "🔧 Starting eMMC optimization for Proxmox VE..."

# Detect eMMC device
EMMC_DEVICE=""
for device in /dev/mmcblk*; do
    if [[ -b "$device" ]]; then
        EMMC_DEVICE="$device"
        break
    fi
done

if [[ -z "$EMMC_DEVICE" ]]; then
    log "⚠️  Warning: No eMMC device detected, applying general flash storage optimizations"
    EMMC_DEVICE="/dev/sda"  # Fallback to first SATA device
fi

log "📱 Target device: $EMMC_DEVICE"

# 1. Configure fstab for reduced writes
log "📝 Optimizing /etc/fstab mount options..."

# Backup original fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Add noatime,commit=600 to ext4 filesystems if not already present
sed -i.bak 's/\(.*ext4.*defaults\)/\1,noatime,commit=600/' /etc/fstab
sed -i 's/\(.*ext4.*errors=remount-ro\)/\1,noatime,commit=600/' /etc/fstab

# Remove duplicate mount options
sed -i 's/,noatime,commit=600,noatime,commit=600/,noatime,commit=600/g' /etc/fstab

log "✅ Updated /etc/fstab with noatime and commit=600 options"

# 2. Configure periodic TRIM instead of continuous
log "⚡ Setting up periodic TRIM..."

# Enable weekly fstrim timer
systemctl enable fstrim.timer
systemctl start fstrim.timer

# Disable continuous TRIM (discard) on swap if present
sed -i 's/\(.*swap.*sw\),discard/\1/' /etc/fstab 2>/dev/null || true

log "✅ Periodic TRIM enabled, continuous TRIM disabled"

# 3. Configure tmpfs for temporary directories
log "💾 Setting up tmpfs for temporary directories..."

# Add tmpfs entries to fstab if not present
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=1G 0 0" >> /etc/fstab
fi

if ! grep -q "tmpfs /var/tmp" /etc/fstab; then
    echo "tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=512M 0 0" >> /etc/fstab
fi

log "✅ Configured tmpfs for /tmp and /var/tmp"

# 4. Optimize systemd journal settings
log "📋 Optimizing systemd journal settings..."

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/emmc-optimization.conf << EOF
[Journal]
# Limit journal size to reduce writes
SystemMaxUse=200M
SystemMaxFileSize=50M
RuntimeMaxUse=100M
RuntimeMaxFileSize=25M
# Compress journal entries
Compress=yes
# Sync every 5 minutes instead of constantly
SyncIntervalSec=300
# Reduce journal verbosity
MaxLevelStore=warning
MaxLevelSyslog=warning
EOF

log "✅ Optimized systemd journal settings"

# 5. Configure kernel parameters for reduced writing
log "⚙️  Configuring kernel parameters..."

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/emmc-optimization.conf << EOF
# eMMC/SSD optimization settings

# Reduce swappiness to minimize swap usage
vm.swappiness=1

# Increase dirty write-back interval
vm.dirty_expire_centisecs=6000
vm.dirty_writeback_centisecs=12000

# Increase dirty memory limits
vm.dirty_background_ratio=15
vm.dirty_ratio=30

# Reduce filesystem check frequency
fs.fsck.default_fsck_interval=0
EOF

log "✅ Configured kernel parameters for reduced writes"

# 6. Set I/O scheduler for flash storage
log "🔄 Setting I/O scheduler..."

# Create udev rule for SSD/eMMC scheduler
cat > /etc/udev/rules.d/60-emmc-scheduler.rules << EOF
# Set deadline scheduler for non-rotating disks (SSD/eMMC)
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"
# Reduce queue depth for eMMC
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/nr_requests}="8"
EOF

log "✅ Configured I/O scheduler for flash storage"

# 7. Configure log rotation
log "📜 Optimizing log rotation..."

# Configure more aggressive log rotation
cat > /etc/logrotate.d/emmc-optimization << EOF
/var/log/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload-or-restart rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/syslog {
    daily
    missingok
    rotate 3
    compress
    delaycompress
    notifempty
    create 640 syslog adm
    postrotate
        systemctl reload-or-restart rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

log "✅ Configured aggressive log rotation"

# 8. Configure Proxmox-specific optimizations
log "🏠 Applying Proxmox-specific optimizations..."

# Optimize Proxmox VE configuration
if [[ -f /etc/pve/datacenter.cfg ]]; then
    # Reduce backup verification frequency
    grep -q "max_workers" /etc/pve/datacenter.cfg || echo "max_workers: 2" >> /etc/pve/datacenter.cfg
fi

# Configure container and VM defaults for eMMC
mkdir -p /etc/pve/qemu-server
mkdir -p /etc/pve/lxc

# Create VM template with SSD optimizations
cat > /etc/pve/snippets/emmc-vm-template.conf << EOF
# VM template optimized for eMMC storage
scsi0: local:100/vm-template-emmc.qcow2,cache=writeback,discard=on,ssd=1
EOF

log "✅ Applied Proxmox-specific optimizations"

# 9. Setup monitoring for eMMC health
log "🔍 Setting up eMMC health monitoring..."

# Create health check script
cat > /usr/local/bin/emmc-health-check.sh << 'EOF'
#!/bin/bash

# eMMC Health Monitoring Script

EMMC_DEVICE=$(ls /dev/mmcblk* 2>/dev/null | head -n1)
LOG_FILE="/var/log/emmc-health.log"

if [[ -z "$EMMC_DEVICE" ]]; then
    echo "[$(date)] No eMMC device found" >> "$LOG_FILE"
    exit 1
fi

# Log eMMC health information
{
    echo "=== eMMC Health Check - $(date) ==="
    echo "Device: $EMMC_DEVICE"
    
    # Check for bad blocks
    if command -v badblocks &> /dev/null; then
        echo "Bad blocks check:"
        badblocks -v "$EMMC_DEVICE" 2>&1 | head -n 10
    fi
    
    # Check filesystem usage
    echo "Filesystem usage:"
    df -h | grep -E "(mmcblk|/$)"
    
    # Check available space
    echo "Available space check:"
    AVAILABLE=$(df / | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE -lt 1048576 ]]; then  # Less than 1GB
        echo "WARNING: Low disk space - ${AVAILABLE}K available"
    fi
    
    echo "=== End Health Check ==="
    echo ""
} >> "$LOG_FILE"
EOF

chmod +x /usr/local/bin/emmc-health-check.sh

# Create systemd timer for health checks
cat > /etc/systemd/system/emmc-health-check.timer << EOF
[Unit]
Description=eMMC Health Check Timer
Requires=emmc-health-check.service

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/emmc-health-check.service << EOF
[Unit]
Description=eMMC Health Check
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/emmc-health-check.sh
User=root
EOF

systemctl daemon-reload
systemctl enable emmc-health-check.timer
systemctl start emmc-health-check.timer

log "✅ eMMC health monitoring configured"

# 10. Create maintenance script
log "🛠️  Creating maintenance script..."

cat > /usr/local/bin/emmc-maintenance.sh << 'EOF'
#!/bin/bash

# eMMC Maintenance Script
# Run this monthly to maintain eMMC health

LOG_FILE="/var/log/emmc-maintenance.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting eMMC maintenance..."

# 1. Manual TRIM
log "Running manual TRIM..."
fstrim -av

# 2. Clear package cache
log "Clearing package cache..."
apt-get clean
apt-get autoremove -y

# 3. Clear old logs
log "Clearing old logs..."
journalctl --vacuum-time=7d
find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true

# 4. Clear temporary files
log "Clearing temporary files..."
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
find /var/tmp -type f -mtime +3 -delete 2>/dev/null || true

# 5. Update locate database efficiently
log "Updating locate database..."
if command -v updatedb &> /dev/null; then
    updatedb --localpaths=/usr --netpaths= --prunepaths="/tmp /var/tmp /var/cache"
fi

# 6. Defragment if needed (ext4)
log "Checking filesystem fragmentation..."
for fs in $(mount | grep ext4 | awk '{print $1}'); do
    if command -v e4defrag &> /dev/null; then
        e4defrag -c "$fs" >> "$LOG_FILE" 2>&1
    fi
done

log "eMMC maintenance completed"
EOF

chmod +x /usr/local/bin/emmc-maintenance.sh

# Create monthly maintenance timer
cat > /etc/systemd/system/emmc-maintenance.timer << EOF
[Unit]
Description=Monthly eMMC Maintenance
Requires=emmc-maintenance.service

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/emmc-maintenance.service << EOF
[Unit]
Description=eMMC Maintenance
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/emmc-maintenance.sh
User=root
EOF

systemctl daemon-reload
systemctl enable emmc-maintenance.timer
systemctl start emmc-maintenance.timer

log "✅ Monthly maintenance configured"

# 11. Configure zswap for memory compression
log "💾 Configuring zswap..."

# Enable zswap for better memory utilization
if ! grep -q "zswap.enabled=1" /etc/default/grub; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 zswap.enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=20"/' /etc/default/grub
    update-grub
    log "✅ zswap configured (requires reboot)"
else
    log "✅ zswap already configured"
fi

# 12. Install and configure useful tools
log "🛠️  Installing useful tools..."

apt-get update
apt-get install -y smartmontools hdparm util-linux e2fsprogs

log "✅ Useful tools installed"

# Final summary
log "🎉 eMMC optimization completed successfully!"
log ""
log "📋 Applied optimizations:"
log "  • Mount options: noatime, commit=600"
log "  • Periodic TRIM enabled"
log "  • tmpfs for temporary directories"
log "  • Optimized systemd journal"
log "  • Reduced swap usage (swappiness=1)"
log "  • Deadline I/O scheduler for flash storage"
log "  • Aggressive log rotation"
log "  • eMMC health monitoring"
log "  • Monthly maintenance tasks"
log "  • zswap memory compression"
log ""
log "⚠️  Important: Reboot required for some changes to take effect"
log ""
log "📊 Monitor eMMC health with:"
log "  sudo cat /var/log/emmc-health.log"
log ""
log "🛠️  Run manual maintenance with:"
log "  sudo /usr/local/bin/emmc-maintenance.sh"

echo ""
echo "🎯 eMMC optimization completed! Please reboot to activate all changes."