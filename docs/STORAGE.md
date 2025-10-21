# 💾 Storage Optimization Guide

## Overview

This guide covers storage optimization for ZimaBoard 2, focusing on eMMC longevity and SSD utilization.

---

## Storage Architecture

### Recommended Setup

- **64GB eMMC**: Operating system and service binaries
- **2TB SSD**: All data, logs, cache, and databases
- **Result**: 90%+ reduction in eMMC writes

### Storage Distribution

```
eMMC (64GB):
├── Ubuntu OS (~20GB)
├── Service binaries (~5GB)
├── System cache (~10GB)
└── Free space (~29GB)

SSD (2TB):
├── /mnt/ssd-data/adguardhome/     # DNS query logs
├── /mnt/ssd-data/nextcloud/       # User files
├── /mnt/ssd-data/squid-cache/     # Proxy cache
├── /mnt/ssd-data/logs/            # System logs
└── /mnt/ssd-backup/               # Automated backups
```

---

## eMMC Optimization

### Automatic Optimizations (Applied by Installer)

1. **Reduced Swappiness**:
   ```bash
   # Check current setting
   cat /proc/sys/vm/swappiness  # Should be 10
   ```

2. **NoAtime Mount Options**:
   ```bash
   # Check mount options
   mount | grep mmcblk0 | grep noatime
   ```

3. **Log Redirection**:
   ```bash
   # Logs moved to SSD
   ls -la /var/log  # Should be symlink to SSD
   ```

4. **Memory Compression**:
   ```bash
   # Check zswap status
   cat /sys/module/zswap/parameters/enabled
   ```

### Manual eMMC Health Monitoring

```bash
# Check eMMC usage
df -h | grep mmcblk0

# Monitor write operations
iostat -x 1 5 | grep mmcblk0

# Check filesystem health
sudo fsck -n /dev/mmcblk0p2
```

---

## SSD Configuration

### Automatic SSD Setup

The installer provides interactive SSD configuration:

1. **Fresh Format** (recommended for new drives)
2. **Use Existing** (preserves current data)
3. **Advanced Setup** (manual configuration)
4. **Skip SSD** (eMMC-only fallback)

### Manual SSD Setup

If you need to configure SSD manually:

```bash
# Identify SSD device
lsblk

# Create partitions (example for /dev/sda)
sudo parted -s /dev/sda mklabel gpt
sudo parted -s /dev/sda mkpart primary ext4 0% 80%
sudo parted -s /dev/sda mkpart primary ext4 80% 100%

# Format partitions
sudo mkfs.ext4 -F /dev/sda1 -L "homelab-data"
sudo mkfs.ext4 -F /dev/sda2 -L "homelab-backup"

# Create mount points
sudo mkdir -p /mnt/ssd-data /mnt/ssd-backup

# Get UUIDs
DATA_UUID=$(blkid -s UUID -o value /dev/sda1)
BACKUP_UUID=$(blkid -s UUID -o value /dev/sda2)

# Add to fstab
echo "UUID=$DATA_UUID /mnt/ssd-data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
echo "UUID=$BACKUP_UUID /mnt/ssd-backup ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab

# Mount all
sudo mount -a
```

### SSD Performance Optimization

```bash
# Enable TRIM support
sudo systemctl enable fstrim.timer
sudo systemctl start fstrim.timer

# Check TRIM support
sudo fstrim -v /mnt/ssd-data

# Set optimal scheduler for SSD
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler
```

---

## Data Migration

### Moving Logs to SSD

```bash
# Stop logging services temporarily
sudo systemctl stop rsyslog

# Copy existing logs
sudo cp -a /var/log/* /mnt/ssd-data/logs/

# Backup original log directory
sudo mv /var/log /var/log.backup

# Create symlink
sudo ln -s /mnt/ssd-data/logs /var/log

# Restart logging
sudo systemctl start rsyslog
```

### Moving Service Data

```bash
# Example: Move MySQL data to SSD
sudo systemctl stop mariadb
sudo mv /var/lib/mysql /mnt/ssd-data/mysql
sudo ln -s /mnt/ssd-data/mysql /var/lib/mysql
sudo systemctl start mariadb
```

---

## Storage Monitoring

### Disk Usage Monitoring

```bash
# Check overall usage
df -h

# Check SSD usage breakdown
sudo du -sh /mnt/ssd-data/*

# Monitor real-time I/O
iotop -a

# Check storage device health
sudo smartctl -H /dev/sda
```

### Automated Monitoring

Create a monitoring script:

```bash
sudo nano /opt/homelab/monitor-storage.sh
```

```bash
#!/bin/bash
# Storage monitoring script

echo "=== Storage Usage Report $(date) ==="

echo "## Overall Disk Usage"
df -h

echo "## eMMC Usage"
df -h | grep mmcblk0

echo "## SSD Usage"
df -h | grep sda

echo "## Service Data Sizes"
sudo du -sh /mnt/ssd-data/* 2>/dev/null

echo "## eMMC Health"
if [ -b /dev/mmcblk0 ]; then
    sudo smartctl -H /dev/mmcblk0 2>/dev/null || echo "Health check not available"
fi

echo "## SSD Health"
if [ -b /dev/sda ]; then
    sudo smartctl -H /dev/sda
fi
```

Make it executable and run weekly:

```bash
sudo chmod +x /opt/homelab/monitor-storage.sh
(crontab -l; echo "0 9 * * 1 /opt/homelab/monitor-storage.sh > /mnt/ssd-backup/storage-report-$(date +%Y%m%d).txt") | crontab -
```

---

## Backup Strategy

### Automated Backups

The installer sets up automated backups:

```bash
# Check backup schedule
crontab -l | grep backup

# Manual backup
sudo tar -czf /mnt/ssd-backup/config-backup-$(date +%Y%m%d).tar.gz \
    /etc/wireguard/ \
    /opt/AdGuardHome/ \
    /var/www/nextcloud/config/ \
    /etc/nginx/sites-available/homelab
```

### Database Backups

```bash
# Backup Nextcloud database
sudo mysqldump -u root -p nextcloud | gzip > /mnt/ssd-backup/nextcloud-db-$(date +%Y%m%d).sql.gz

# Automated database backup
(crontab -l; echo "0 2 * * * mysqldump -u root --password=admin123 nextcloud | gzip > /mnt/ssd-backup/nextcloud-db-$(date +%Y%m%d).sql.gz") | crontab -
```

### Restore Procedures

```bash
# Restore configuration
sudo tar -xzf /mnt/ssd-backup/config-backup-YYYYMMDD.tar.gz -C /

# Restore database
gunzip < /mnt/ssd-backup/nextcloud-db-YYYYMMDD.sql.gz | mysql -u root -p nextcloud
```

---

## Performance Tuning

### I/O Scheduling

```bash
# Check current scheduler
cat /sys/block/mmcblk0/queue/scheduler  # eMMC
cat /sys/block/sda/queue/scheduler      # SSD

# Optimize for eMMC (deadline scheduler)
echo deadline | sudo tee /sys/block/mmcblk0/queue/scheduler

# Optimize for SSD (mq-deadline or none)
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler
```

### Cache Configuration

```bash
# Reduce dirty writeback time for eMMC
echo 5 | sudo tee /proc/sys/vm/dirty_writeback_centisecs

# Increase cache pressure for better memory usage
echo 50 | sudo tee /proc/sys/vm/vfs_cache_pressure
```

### Service-Specific Optimizations

```bash
# Optimize MariaDB for SSD
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Add these lines:
# innodb_flush_method = O_DIRECT
# innodb_log_file_size = 256M
# innodb_buffer_pool_size = 512M

# Optimize Redis for memory
sudo nano /etc/redis/redis.conf

# Set appropriate memory limits:
# maxmemory 256mb
# maxmemory-policy allkeys-lru
```

---

## Troubleshooting

### eMMC Issues

```bash
# Check for errors
dmesg | grep -i mmc

# Check filesystem
sudo fsck -n /dev/mmcblk0p2

# Monitor health
watch -n 1 'cat /sys/block/mmcblk0/stat'
```

### SSD Issues

```bash
# Check SMART status
sudo smartctl -a /dev/sda

# Check for bad blocks
sudo badblocks -v /dev/sda

# Test read/write speed
sudo hdparm -tT /dev/sda
```

### Space Issues

```bash
# Find large files
sudo find /mnt/ssd-data -type f -size +100M -exec ls -lh {} \;

# Clean up logs
sudo journalctl --vacuum-size=100M

# Clean up cache
sudo apt clean
sudo apt autoremove
```

### Mount Issues

```bash
# Check fstab syntax
sudo mount -a

# Remount with correct options
sudo mount -o remount,noatime /mnt/ssd-data

# Check filesystem type
file -s /dev/sda1
```

---

## Storage Expansion

### Adding Additional Storage

```bash
# Identify new drive
lsblk

# Create partition and format
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary ext4 0% 100%
sudo mkfs.ext4 -F /dev/sdb1 -L "extra-storage"

# Mount permanently
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=$UUID /mnt/extra ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
sudo mkdir /mnt/extra
sudo mount /mnt/extra
```

### RAID Configuration (Optional)

For redundancy with multiple SSDs:

```bash
# Install mdadm
sudo apt install mdadm

# Create RAID 1 array
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/sda /dev/sdb

# Format and mount
sudo mkfs.ext4 /dev/md0
sudo mkdir /mnt/raid
sudo mount /dev/md0 /mnt/raid
```

---

## Best Practices

1. **Monitor regularly**: Check storage usage weekly
2. **Backup frequently**: Automated daily/weekly backups
3. **Update firmware**: Keep SSD firmware current
4. **Plan capacity**: Monitor growth trends
5. **Test restores**: Verify backup integrity
6. **Document changes**: Track configuration modifications

---

For storage-related troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
