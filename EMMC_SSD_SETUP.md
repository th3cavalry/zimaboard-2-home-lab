# eMMC + SSD Optimized Setup for ZimaBoard 2

## Overview

This guide explains how to install Ubuntu on the ZimaBoard 2's 64GB eMMC while directing **ALL write-intensive operations** to the SSD. This approach maximizes eMMC lifespan by keeping only the core operating system on eMMC and moving all frequently written data to the SSD.

### Why This Setup?

The eMMC storage has limited write cycles (typically 3,000-5,000 program/erase cycles). By keeping the OS on eMMC but redirecting writes to the SSD, you get:

- **Extended eMMC lifespan**: Core OS files are rarely written to
- **Better performance**: SSDs handle frequent writes better than eMMC
- **System reliability**: OS remains bootable even with heavy disk I/O
- **Optimal use of hardware**: Leverages both storage types for their strengths

### Partitioning Strategy

**eMMC (64GB) will contain:**
- EFI System Partition (ESP): 500MB
- Root partition (/): 5-10GB (read-mostly OS files)

**SSD (2TB) will contain:**
- /home: User data and configurations (~500GB or more)
- /var: System logs, caches, package manager data (~100GB)
- /tmp: Temporary files (~20GB)
- /usr/local: Locally installed software (optional, ~50GB)
- /mnt/ssd: Remaining space for Docker, Samba shares, etc.

---

## Part 1: Prepare for Installation

### Step 1.1: Backup Data

⚠️ **WARNING**: This process will erase all data on both the eMMC and SSD. Backup everything important before proceeding.

### Step 1.2: Create Installation Media

1. **Download Ubuntu Server 22.04 LTS**:
   - Visit: https://ubuntu.com/download/server
   - Choose the version for your architecture (x86-64 for ZimaBoard 2)

2. **Create Bootable USB**:
   - **Windows**: Use [Rufus](https://rufus.ie/) or [balenaEtcher](https://www.balena.io/etcher/)
   - **macOS/Linux**: Use [balenaEtcher](https://www.balena.io/etcher/) or `dd` command

### Step 1.3: Identify Your Drives

Boot from the Ubuntu Live USB and identify your storage devices:

```bash
# Boot into Live environment, then open a terminal
lsblk

# Example output:
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda           8:0    0   1.8T  0 disk           <- Your 2TB SSD
# sdb           8:16   0 465.8G  0 disk           <- Your 500GB HDD (for cache)
# mmcblk0     179:0    0  59.6G  0 disk           <- Your 64GB eMMC (for OS)
```

In this guide:
- **eMMC** will be `/dev/mmcblk0`
- **SSD** will be `/dev/sda`
- **HDD** will be `/dev/sdb` (used later for cache only)

---

## Part 2: Ubuntu Installation with Custom Partitioning

### Step 2.1: Start Ubuntu Installation

1. **Boot from Live USB**: Insert the USB drive and power on the ZimaBoard
2. **Access Boot Menu**: Press F7, F12, or Del (depends on BIOS)
3. **Select USB Drive**: Choose your USB installation media
4. **Start Installation**: Select "Install Ubuntu Server"

### Step 2.2: Complete Initial Setup

Follow the installation prompts:
- Select language and keyboard layout
- Configure network (set static IP: 192.168.8.2 if following main README)
- Create an admin user account
- **IMPORTANT**: When you reach "Storage configuration", select **"Custom storage layout"** or **"Something else"**

### Step 2.3: Partition the eMMC

Using the partition editor in the installer:

#### EFI System Partition
- Device: `/dev/mmcblk0`
- Size: 500 MB
- Type: EFI System Partition
- Format: FAT32
- Mount point: `/boot/efi`

#### Root Partition
- Device: `/dev/mmcblk0`
- Size: 8 GB (or 10 GB if you have space)
- Type: ext4
- Format: Yes
- Mount point: `/`

**Note**: Some installers create these automatically. Just ensure the root partition is small (5-10GB) and on the eMMC.

### Step 2.4: Partition the SSD

Create separate partitions on the SSD for write-intensive directories:

#### /home Partition
- Device: `/dev/sda`
- Size: 500 GB (adjust based on your needs)
- Type: ext4
- Format: Yes
- Mount point: `/home`

#### /var Partition
- Device: `/dev/sda`
- Size: 100 GB
- Type: ext4
- Format: Yes
- Mount point: `/var`

#### /tmp Partition
- Device: `/dev/sda`
- Size: 20 GB
- Type: ext4
- Format: Yes
- Mount point: `/tmp`

#### /usr/local Partition (Optional)
- Device: `/dev/sda`
- Size: 50 GB
- Type: ext4
- Format: Yes
- Mount point: `/usr/local`

#### Data Partition (Remaining Space)
- Device: `/dev/sda`
- Size: Remaining space (~1.3TB)
- Type: ext4
- Format: Yes
- Mount point: `/mnt/ssd`

**Alternative**: If the installer doesn't allow multiple partitions easily, you can create just `/home` during installation and add the others after (see Part 3).

### Step 2.5: Complete Installation

1. Review the partition layout carefully
2. Confirm and proceed with installation
3. Select "Install OpenSSH server" when prompted
4. Complete the installation and reboot
5. Remove the USB drive when prompted

---

## Part 3: Post-Installation Configuration

If you only created `/home` during installation, or need to adjust partitioning:

### Step 3.1: Verify Current Setup

```bash
# SSH into your ZimaBoard
ssh your-username@192.168.8.2

# Check current mounts
df -h

# Check partition layout
lsblk
sudo fdisk -l /dev/sda
```

### Step 3.2: Create Additional Partitions (If Needed)

If you didn't create all partitions during installation:

⚠️ **WARNING**: This is advanced and can break your system if done incorrectly. Consider doing this during installation instead.

```bash
# Use parted to create partitions on remaining SSD space
# This example assumes /home already exists and you have unallocated space

# Install parted if needed
sudo apt update
sudo apt install -y parted

# Check current partitions
sudo parted /dev/sda print

# Create /var partition (adjust start/end as needed)
# sudo parted /dev/sda mkpart primary ext4 500GB 600GB

# Create /tmp partition
# sudo parted /dev/sda mkpart primary ext4 600GB 620GB

# Format the new partitions
# sudo mkfs.ext4 /dev/sda3  # /var
# sudo mkfs.ext4 /dev/sda4  # /tmp
```

### Step 3.3: Configure /etc/fstab

The `/etc/fstab` file controls which partitions mount at boot. We'll use UUIDs for reliability.

#### Get Partition UUIDs

```bash
# Get UUIDs for all SSD partitions
sudo blkid /dev/sda*

# Example output:
# /dev/sda1: UUID="abc12345-home-uuid-here" TYPE="ext4" LABEL="home"
# /dev/sda2: UUID="def67890-var-uuid-here" TYPE="ext4" LABEL="var"
# /dev/sda3: UUID="ghi13579-tmp-uuid-here" TYPE="ext4" LABEL="tmp"
# /dev/sda4: UUID="jkl24680-data-uuid-here" TYPE="ext4" LABEL="ssd-data"

# Copy these UUIDs - you'll need them next
```

#### Edit /etc/fstab

```bash
# Backup the current fstab
sudo cp /etc/fstab /etc/fstab.backup

# Edit fstab
sudo nano /etc/fstab
```

Add or verify these entries (replace UUIDs with your actual values):

```
# eMMC partitions (should already exist)
UUID=your-efi-uuid-here    /boot/efi  vfat    umask=0077  0  1
UUID=your-root-uuid-here   /          ext4    defaults    0  1

# SSD partitions for write-intensive operations
UUID=your-home-uuid-here        /home       ext4    defaults,nofail    0  2
UUID=your-var-uuid-here         /var        ext4    defaults,nofail    0  2
UUID=your-tmp-uuid-here         /tmp        ext4    defaults,nofail    0  2
UUID=your-usrlocal-uuid-here    /usr/local  ext4    defaults,nofail    0  2
UUID=your-data-uuid-here        /mnt/ssd    ext4    defaults,nofail    0  2

# HDD for cache (format this later following main README)
UUID=your-hdd-uuid-here         /mnt/hdd    ext4    defaults,nofail    0  2
```

**fstab Options Explained:**
- `defaults`: Use default mount options (rw, suid, dev, exec, auto, nouser, async)
- `nofail`: Don't prevent boot if the drive is missing (important for external drives)
- `0`: Don't dump (backup) this partition
- `2`: Check filesystem after root filesystem (0=don't check, 1=check first, 2=check after)

**Optional Performance Tuning:**

For even better eMMC longevity, add these options to SSD entries:

```
UUID=your-home-uuid-here    /home    ext4    defaults,nofail,noatime,commit=60    0  2
```

- `noatime`: Don't update file access times (reduces writes)
- `commit=60`: Reduce filesystem commit frequency from 5s to 60s (fewer writes, but more data loss risk on crash)

### Step 3.4: Migrate Existing Data (If Partitions Were Added Post-Install)

⚠️ **WARNING**: Only do this if you created `/var` or `/tmp` partitions AFTER installation.

If you already installed with everything on eMMC and are now moving directories to SSD:

```bash
# Boot into recovery mode or use Live USB to safely move data
# DO NOT do this on a running system!

# Example for moving /var (DO THIS FROM LIVE USB OR RECOVERY):
# 1. Boot from Live USB
# 2. Mount partitions:
sudo mkdir -p /mnt/old-root /mnt/new-var
sudo mount /dev/mmcblk0p2 /mnt/old-root
sudo mount /dev/sda2 /mnt/new-var

# 3. Copy data:
sudo rsync -avxHAX /mnt/old-root/var/ /mnt/new-var/

# 4. Verify copy completed successfully:
ls -la /mnt/new-var

# 5. Rename old directory (don't delete yet, just in case):
sudo mv /mnt/old-root/var /mnt/old-root/var.old

# 6. Create empty mount point:
sudo mkdir /mnt/old-root/var

# 7. Update fstab (see section 3.3)

# 8. Reboot and verify everything works

# 9. After confirming system works, delete old data:
sudo rm -rf /var.old
```

Repeat for `/tmp` if needed. `/home` and `/usr/local` are safer to move on a running system.

### Step 3.5: Mount and Verify

```bash
# Mount all filesystems from fstab
sudo mount -a

# Verify all partitions mounted correctly
df -h

# Expected output should show:
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/mmcblk0p2  7.3G  2.1G  4.9G  30% /
# /dev/sda1       492G   73M  467G   1% /home
# /dev/sda2        99G  233M   94G   1% /var
# /dev/sda3        20G   45M   19G   1% /tmp
# /dev/sda4        49G  115M   47G   1% /usr/local
# /dev/sda5       1.3T  128M  1.2T   1% /mnt/ssd

# Check for any mount errors
dmesg | grep -i "mount"

# Verify write permissions
touch /var/test-write.txt && rm /var/test-write.txt
touch /tmp/test-write.txt && rm /tmp/test-write.txt
touch /home/$USER/test-write.txt && rm /home/$USER/test-write.txt
```

### Step 3.6: Additional Optimizations

#### Move Docker to SSD

Docker images and containers generate significant writes. Move Docker to the SSD:

```bash
# Stop Docker (install it first if not installed)
sudo systemctl stop docker

# Create Docker directory on SSD
sudo mkdir -p /mnt/ssd/docker

# Edit Docker daemon configuration
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

Add this content:

```json
{
  "data-root": "/mnt/ssd/docker"
}
```

Continue:

```bash
# Copy existing Docker data if any
sudo rsync -aP /var/lib/docker/ /mnt/ssd/docker/

# Restart Docker
sudo systemctl start docker

# Verify new location
docker info | grep "Docker Root Dir"
# Should show: Docker Root Dir: /mnt/ssd/docker

# After confirming it works, remove old data
sudo rm -rf /var/lib/docker
```

#### Reduce System Logging (Optional)

To further reduce writes to `/var`:

```bash
# Edit systemd journal configuration
sudo nano /etc/systemd/journald.conf
```

Uncomment and modify these lines:

```ini
[Journal]
SystemMaxUse=100M
SystemKeepFree=500M
SystemMaxFileSize=10M
RuntimeMaxUse=100M
```

Restart journald:

```bash
sudo systemctl restart systemd-journald
```

#### Disable Swap (Optional)

With 16GB RAM, swap is rarely needed and generates writes:

```bash
# Check if swap is enabled
swapon --show

# Disable swap
sudo swapoff -a

# Remove swap from fstab
sudo nano /etc/fstab
# Comment out or remove any swap line
```

---

## Part 4: Verification and Testing

### Step 4.1: Verify Partition Layout

```bash
# Check all mounts
df -h

# Verify using correct filesystems
mount | grep "^/dev"

# Check which files are on eMMC vs SSD
du -sh /* 2>/dev/null

# Root should be small (OS only)
du -sh /
# Should be under 8GB if properly configured
```

### Step 4.2: Test Write Performance

```bash
# Test write speed to /var (on SSD)
dd if=/dev/zero of=/var/test bs=1M count=1024 oflag=direct
# Should show good SSD speeds (100+ MB/s)

# Test write speed to /tmp (on SSD)
dd if=/dev/zero of=/tmp/test bs=1M count=1024 oflag=direct

# Clean up
rm /var/test /tmp/test
```

### Step 4.3: Monitor eMMC Writes

```bash
# Install iotop to monitor disk I/O
sudo apt install -y iotop

# Monitor disk writes (run for a few minutes during normal use)
sudo iotop -oPa

# Most writes should go to /dev/sda (SSD), not /dev/mmcblk0 (eMMC)
```

---

## Important Considerations

### External Drive Reliability

⚠️ **CRITICAL**: With this setup, your **SSD must be reliable and always connected**. Since `/var`, `/home`, and `/tmp` are on the SSD:

- If the SSD fails or disconnects, the system will have serious issues
- The `nofail` option allows boot to continue, but many things won't work
- Regular backups of `/home` are essential
- Monitor SSD health regularly

### Check SSD Health

```bash
# Install smartmontools
sudo apt install -y smartmontools

# Check SSD health
sudo smartctl -a /dev/sda

# Look for:
# - Reallocated_Sector_Ct (should be low)
# - Wear_Leveling_Count (shows remaining life)
# - Temperature (should be reasonable)
```

### Backup Strategy

Since critical data is on the SSD, implement regular backups:

```bash
# Backup /home to external drive or network storage
rsync -avz /home/ /path/to/backup/home/

# Backup system configuration
sudo tar czf /mnt/backup/system-config.tar.gz \
  /etc/fstab \
  /etc/docker \
  /etc/samba \
  /opt/AdGuardHome
```

### Power Management

Ensure the SSD doesn't enter power-saving modes that could cause issues:

```bash
# Check current power management settings
sudo hdparm -I /dev/sda | grep -i power

# Disable APM (Advanced Power Management) if causing issues
sudo hdparm -B 255 /dev/sda

# Make permanent by adding to /etc/hdparm.conf:
sudo nano /etc/hdparm.conf
# Add:
# /dev/sda {
#     apm = 255
# }
```

---

## Troubleshooting

### System Won't Boot After Changes

1. **Boot from Live USB**
2. **Mount partitions**:
   ```bash
   sudo mount /dev/mmcblk0p2 /mnt
   sudo mount /dev/sda1 /mnt/home
   sudo mount /dev/sda2 /mnt/var
   ```
3. **Check and fix /etc/fstab**:
   ```bash
   sudo nano /mnt/etc/fstab
   # Verify UUIDs are correct
   # Use `sudo blkid` to check
   ```
4. **Reboot**

### /var or /home Not Mounting

```bash
# Check fstab syntax
sudo mount -a
# Look for error messages

# Verify partition UUID
sudo blkid /dev/sda2
# Compare with /etc/fstab

# Check filesystem
sudo fsck /dev/sda2
```

### High eMMC Writes Despite Configuration

```bash
# Monitor what's writing to eMMC
sudo iotop -oPa

# Check if any system logs are still on eMMC
ls -la /var/log
# This should be on SSD (/var is on SSD)

# Check for services using eMMC
lsof +L1 | grep mmcblk0
```

---

## Summary

This setup provides:

✅ **eMMC longevity**: Core OS on eMMC with minimal writes  
✅ **Performance**: All writes go to faster SSD  
✅ **Reliability**: System remains bootable even with heavy I/O  
✅ **Flexibility**: Easy to expand or reconfigure partitions  
✅ **Optimized for ZimaBoard 2**: Leverages 64GB eMMC + 2TB SSD properly  

**What's on eMMC (read-mostly):**
- Boot files (EFI)
- Core OS files (/)
- Binaries and libraries

**What's on SSD (write-intensive):**
- User data (/home)
- System logs and caches (/var)
- Temporary files (/tmp)
- Docker data (/mnt/ssd/docker)
- Application data (/mnt/ssd/fileshare)

Continue to the main [README.md](README.md) to set up your homelab services!

---

**Happy computing!**