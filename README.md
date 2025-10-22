# 🏠 ZimaBoard Homelab Services

**A complete, production-ready homelab solution with TWO installation paths**

[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![Ubuntu Server](https://img.shields.io/badge/Ubuntu-Server%2022.04%20LTS-orange)](https://ubuntu.com/server)
[![ZimaBoard 2](https://img.shields.io/badge/ZimaBoard-2%20Supported-blue)](https://www.zimaspace.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 📋 Introduction

This repository provides a complete homelab configuration specifically designed for the **ZimaBoard 2** hardware platform. It offers **TWO distinct installation paths** to suit different needs:

- **Path A**: Fully Containerized (Docker) - **Recommended for most users**
- **Path B**: Bare-Metal/Hybrid - For performance-focused users

### Project Goals

- **Network Security**: DNS-based ad blocking and filtering with AdGuard Home
- **Bandwidth Optimization**: Game/OS update caching to reduce cellular data usage with Lancache
- **File Storage**: Simple, high-performance network file sharing with Samba (approx. 1TB)
- **eMMC Longevity**: Optimized to minimize write cycles on the 64GB eMMC boot drive
- **Optional Monitoring**: Network health tracking and intrusion prevention

### Core Services

- **🛡️ AdGuard Home**: Network-wide ad blocking and DNS security
- **⚡ Lancache**: Gaming and software download cache (Steam, Epic Games, etc.)
- **📁 Samba**: Simple, high-performance network file storage (1TB)
- **📊 Optional Monitoring**: Uptime Kuma for service health tracking
- **🔒 Optional Security**: CrowdSec for intrusion prevention

---

## 📋 Hardware Requirements

This setup is optimized for the following specifications:

### Server Hardware
- **ZimaBoard 2**
  - CPU: x86-64 Intel N100 processor
  - RAM: 16GB
  - Storage (OS): 64GB eMMC
  - Storage (Data): 1x 2TB SSD
  - Storage (Cache): 1x 500GB HDD
  - Network: Dual Gigabit Ethernet NICs

### Network Hardware
- **GL.iNet x3000 Router**
  - Configured with cellular broadband connection
  - ZimaBoard connected via Ethernet to LAN port
  - All client devices connect wirelessly

### Network Configuration
- **ZimaBoard Static IP**: 192.168.8.2 (only hardwired device)
- **All client devices**: Connected wirelessly to x3000
- **Internet**: Cellular broadband (bandwidth optimization critical)

---

## 🗂️ Repository Structure

```
/zimaboard-homelab-services/
├── README.md                 # This file - Main guide with "Choose Your Path"
│
├── docker-compose.yml        # Path A: Fully Containerized
├── .env.example              # Path A: Environment configuration
│
├── bare-metal/
│   ├── install.sh            # Path B: Main installation script
│   ├── docker-compose.hybrid.yml # Path B: Docker for Lancache/Optional
│   └── .env.hybrid.example   # Path B: Docker environment config
│
└── configs/
    └── samba/
        └── smb.conf          # Pre-configured Samba config file
```

---

## 🚀 Section 1: Host Preparation (Common to Both Paths)

This section covers the manual setup of your ZimaBoard 2 before choosing your installation path. **Both Path A and Path B require these steps.**

### Step 1.1: Install Ubuntu Server 22.04 LTS

This guide assumes you will install **Ubuntu Server 22.04 LTS** on your ZimaBoard 2's 64GB eMMC storage.

**Installation Steps:**

1. Download Ubuntu Server 22.04 LTS from [ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Create a bootable USB drive:
   - **Windows**: Use [Rufus](https://rufus.ie/) or [Etcher](https://www.balena.io/etcher/)
   - **Linux/Mac**: Use `dd` command or [Etcher](https://www.balena.io/etcher/)
3. Boot ZimaBoard from USB:
   - Insert USB drive into ZimaBoard
   - Power on and press F2 or Delete to enter BIOS
   - Set USB as first boot device
   - Save and exit
4. Follow Ubuntu installation wizard:
   - Select language and keyboard layout
   - Configure network with **static IP: 192.168.8.2**
   - Create an admin user account
   - Select "Install OpenSSH server" when prompted
   - **Important**: Install to the eMMC drive (usually /dev/mmcblk0)
   - Complete installation and reboot

**⚠️ eMMC Longevity Considerations:**

The 64GB eMMC has limited write cycles (typically 3,000-5,000 cycles). To maximize its lifespan:

- **Minimize swap usage**: With 16GB RAM, swap is rarely needed
- **Use external storage**: Store all service data on SSD/HDD, not eMMC
- **Reduce logging**: Configure services to log to external storage or reduce log levels
- **Disable unnecessary services**: Remove services that frequently write to disk

We'll implement these optimizations during setup.

**💡 Advanced Setup Option:**

For **maximum eMMC longevity**, consider the advanced partitioning setup in [EMMC_SSD_SETUP.md](EMMC_SSD_SETUP.md). This approach installs Ubuntu with a custom partition layout that keeps only the core OS on eMMC (5-10GB) while directing **ALL write-intensive operations** (/home, /var, /tmp) to the SSD. This requires more advanced setup during installation but provides the best protection for eMMC lifespan. The standard setup described in this README is sufficient for most users.

### Step 1.2: Install Docker and Docker Compose

**Both paths require Docker** (Path A uses it for all services, Path B uses it for Lancache and optional services).

SSH into your ZimaBoard and install Docker:

```bash
# SSH into ZimaBoard
ssh your-username@192.168.8.2

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
exit
# SSH back in
ssh your-username@192.168.8.2

# Verify installation
docker --version
docker compose version
```

**eMMC Optimization - Move Docker to External Storage (Optional but Recommended):**

By default, Docker stores images and containers on the eMMC. To preserve eMMC lifespan:

```bash
# Stop Docker
sudo systemctl stop docker

# Move Docker data directory to SSD (after mounting in next step)
# We'll do this after Step 1.3

# For now, just note that this optimization exists
```

### Step 1.3: Prepare Storage Drives (Critical Step)

This step prepares your 2TB SSD and 500GB HDD for use with the homelab services.

#### 1.3.1: Identify Your Drives

```bash
# List all block devices
lsblk

# Example output:
# NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda           8:0    0   1.8T  0 disk           <- Your 2TB SSD
# sdb           8:16   0 465.8G  0 disk           <- Your 500GB HDD
# mmcblk0     179:0    0  59.6G  0 disk           <- Your 64GB eMMC (OS)
# ├─mmcblk0p1 179:1    0     1G  0 part /boot/efi
# └─mmcblk0p2 179:2    0  58.6G  0 part /

# Check if drives are already formatted
sudo fdisk -l /dev/sda
sudo fdisk -l /dev/sdb
```

#### 1.3.2: Format the Drives (CAUTION: This erases all data!)

**⚠️ WARNING**: The following commands will **ERASE ALL DATA** on the specified drives. Make sure you have the correct device names!

```bash
# Format the 2TB SSD (adjust /dev/sda if needed)
sudo parted /dev/sda --script mklabel gpt
sudo parted /dev/sda --script mkpart primary ext4 0% 100%
sudo mkfs.ext4 -F /dev/sda1 -L "SSD-Data"

# Format the 500GB HDD (adjust /dev/sdb if needed)
sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart primary ext4 0% 100%
sudo mkfs.ext4 -F /dev/sdb1 -L "HDD-Cache"
```

#### 1.3.3: Create Mount Points

```bash
# Create mount point directories
sudo mkdir -p /mnt/ssd
sudo mkdir -p /mnt/hdd

# Set ownership to your user
sudo chown -R $USER:$USER /mnt/ssd /mnt/hdd
```

#### 1.3.4: Configure Automatic Mounting (fstab)

Get the UUIDs of your new partitions:

```bash
# Get UUIDs
sudo blkid /dev/sda1
sudo blkid /dev/sdb1

# Example output:
# /dev/sda1: LABEL="SSD-Data" UUID="abc12345-6789-..." TYPE="ext4"
# /dev/sdb1: LABEL="HDD-Cache" UUID="def67890-1234-..." TYPE="ext4"
```

Edit `/etc/fstab` to add automatic mount entries:

```bash
sudo nano /etc/fstab
```

Add these lines at the end (replace UUIDs with your actual values):

```
# 2TB SSD for data storage
UUID=abc12345-6789-your-actual-uuid-here  /mnt/ssd  ext4  defaults,nofail  0  2

# 500GB HDD for cache storage  
UUID=def67890-1234-your-actual-uuid-here  /mnt/hdd  ext4  defaults,nofail  0  2
```

**eMMC Optimization - Reduce Commit Interval (Optional):**

Add `commit=60` to reduce write frequency:

```
UUID=abc12345-6789-your-actual-uuid-here  /mnt/ssd  ext4  defaults,nofail,commit=60  0  2
UUID=def67890-1234-your-actual-uuid-here  /mnt/hdd  ext4  defaults,nofail,commit=60  0  2
```

Mount the drives and verify:

```bash
# Mount all filesystems from fstab
sudo mount -a

# Verify mounts
df -h | grep mnt

# Should show:
# /dev/sda1       1.8T   24K  1.7T   1% /mnt/ssd
# /dev/sdb1       458G   24K  435G   1% /mnt/hdd
```

#### 1.3.5: Create Service Data Directories

```bash
# Create directories for services
sudo mkdir -p /mnt/ssd/fileshare
sudo mkdir -p /mnt/hdd/lancache
sudo mkdir -p /mnt/hdd/lancache-logs

# Set permissions (important for Samba and Lancache)
sudo chmod -R 777 /mnt/ssd/fileshare
sudo chmod -R 777 /mnt/hdd/lancache
sudo chmod -R 777 /mnt/hdd/lancache-logs
```

#### 1.3.6: Move Docker to SSD (eMMC Optimization)

**Optional but highly recommended to preserve eMMC:**

```bash
# Stop Docker
sudo systemctl stop docker

# Create Docker directory on SSD
sudo mkdir -p /mnt/ssd/docker

# Edit Docker daemon configuration
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
# Copy existing Docker data (if any)
sudo rsync -aP /var/lib/docker/ /mnt/ssd/docker/

# Restart Docker
sudo systemctl start docker

# Verify new location
docker info | grep "Docker Root Dir"
# Should show: Docker Root Dir: /mnt/ssd/docker

# Remove old Docker data (after verifying everything works)
# sudo rm -rf /var/lib/docker
```

### Step 1.4: Clone the Repository

```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/th3cavalry/zimaboard-2-home-lab.git
cd zimaboard-2-home-lab
```

**✅ Host Preparation Complete!**

You are now ready to choose your installation path.

---

## 🛤️ Section 2: Choose Your Installation Path

You now have a choice between two installation approaches:

### Path A: Fully Containerized (Docker) ⭐ **RECOMMENDED**

**What it is**: All services (AdGuard Home, Lancache, Samba) run in Docker containers.

**Pros:**
- ✅ **Simplest setup**: Single `docker compose up -d` command
- ✅ **Easy updates**: Pull new images and restart containers
- ✅ **Better isolation**: Each service in its own container
- ✅ **Easier troubleshooting**: Clear separation of concerns
- ✅ **Portable**: Move to different hardware easily
- ✅ **Recommended for beginners**: Less manual configuration

**Cons:**
- ⚠️ Slightly more resource overhead (minimal on 16GB RAM)
- ⚠️ May have tiny performance penalty for Samba (usually unnoticeable)

**Who should choose Path A:**
- First-time homelab users
- Users who want simple, stable, reproducible setups
- Users who value ease of maintenance over maximum performance
- Users who want to easily enable/disable services

**Continue to**: [Section 3: Path A - Fully Containerized Guide](#-section-3-path-a---fully-containerized-guide)

---

### Path B: Bare-Metal/Hybrid

**What it is**: AdGuard Home and Samba run directly on the host OS. Lancache and optional services run in Docker (hybrid approach).

**Why hybrid?** Lancache is a complex multi-container system that's impractical to install bare-metal. Running it in Docker is actually the recommended approach even for bare-metal setups.

**Pros:**
- ✅ **Maximum performance**: Native Samba has best file I/O
- ✅ **Better host integration**: Services use systemd directly
- ✅ **Learning opportunity**: Understand how services work
- ✅ **Flexibility**: Full control over service configuration

**Cons:**
- ⚠️ **More complex setup**: Requires manual installation steps
- ⚠️ **Harder to maintain**: Updates require manual intervention
- ⚠️ **Harder to troubleshoot**: Services integrated with host OS
- ⚠️ **Less portable**: Harder to migrate to new hardware
- ⚠️ **More manual configuration**: Edit config files directly

**Who should choose Path B:**
- Advanced users comfortable with Linux system administration
- Users who need absolute maximum Samba performance
- Users who want to learn system-level service management
- Users with specific customization needs

**Continue to**: [Section 4: Path B - Bare-Metal/Hybrid Guide](#-section-4-path-b---bare-metalhybrid-guide)

---

## 🐳 Section 3: Path A - Fully Containerized Guide

**Prerequisites**: You must have completed [Section 1: Host Preparation](#-section-1-host-preparation-common-to-both-paths)

### Step 3.1: Configure Environment Variables

```bash
# Make sure you're in the repository directory
cd ~/zimaboard-2-home-lab

# Copy the example environment file
cp .env.example .env

# Edit the configuration
nano .env
```

**Required Configuration Changes:**

At minimum, update these values in `.env`:

```bash
# Your ZimaBoard's IP address
SERVER_IP=192.168.8.2

# Your timezone (find yours at: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
TIMEZONE=America/New_York

# Storage paths (should match what you created in Section 1)
DATA_PATH_SSD=/mnt/ssd
DATA_PATH_HDD=/mnt/hdd

# Optional: Adjust cache size based on available space (in GB)
LANCACHE_MAX_SIZE=400
```

Save and exit (Ctrl+X, then Y, then Enter).

### Step 3.2: Disable systemd-resolved (Critical for DNS Port 53)

**⚠️ IMPORTANT**: Ubuntu's `systemd-resolved` service runs on port 53 by default, which will conflict with AdGuard Home's DNS server. You **must** disable it before deploying the services.

#### Option A: Disable systemd-resolved Completely (Recommended)

This is the simplest approach and works best for a dedicated homelab server:

```bash
# Stop and disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Remove the existing resolv.conf symlink
sudo rm /etc/resolv.conf

# Create a new resolv.conf with direct DNS servers
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf

# Make the file immutable to prevent automatic changes
sudo chattr +i /etc/resolv.conf

# Verify port 53 is now free
sudo lsof -i :53
# Should return nothing or error (port is free)
```

#### Option B: Configure systemd-resolved to Use Different Port (Alternative)

If you want to keep systemd-resolved for some reason:

```bash
# Edit resolved configuration
sudo nano /etc/systemd/resolved.conf
```

Add or modify these lines:

```
[Resolve]
DNSStubListener=no
DNS=1.1.1.1 1.0.0.1
```

Save and restart:

```bash
# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Update resolv.conf
sudo rm /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Verify port 53 is free
sudo lsof -i :53
```

**After completing either option**, verify that port 53 is available:

```bash
# This command should return nothing (port is free)
sudo lsof -i :53

# Or this should show no service on port 53
sudo netstat -tulpn | grep :53
```

### Step 3.3: Deploy All Services

```bash
# Start all services
docker compose up -d

# Verify services are running
docker compose ps

# View logs (optional)
docker compose logs -f
```

**Expected Output:**

```
NAME                IMAGE                              STATUS
adguardhome         adguard/adguardhome:latest         Up 10 seconds
lancache            lancachenet/monolithic:latest      Up 10 seconds
samba               dperson/samba:latest               Up 10 seconds
```

### Step 3.4: Verify Service Health

```bash
# Check AdGuard Home
curl http://192.168.8.2:3000

# Check container logs
docker compose logs adguardhome
docker compose logs lancache
docker compose logs samba

# Check resource usage
docker stats --no-stream
```

**✅ Path A Deployment Complete!**

Continue to [Section 5: Post-Installation Configuration](#️-section-5-post-installation-configuration-common-to-both-paths) for next steps.

---

## 🔧 Section 4: Path B - Bare-Metal/Hybrid Guide

**Prerequisites**: You must have completed [Section 1: Host Preparation](#-section-1-host-preparation-common-to-both-paths)

### ⚠️ Understanding the Hybrid Approach

Path B is called "Bare-Metal/Hybrid" because:

- **Bare-Metal**: AdGuard Home and Samba are installed directly on the host OS
- **Hybrid**: Lancache and optional services run in Docker containers

**Why not pure bare-metal?**

Lancache is actually a collection of Docker containers (monolithic image, DNS server, etc.) designed to work together. Installing it bare-metal would require manually setting up nginx with custom configurations, DNS proxy servers, and complex caching logic. The official Lancache project **recommends** using their Docker images even for "bare-metal" setups.

### Step 4.1: Run the Bare-Metal Installation Script

```bash
# Navigate to the bare-metal directory
cd ~/zimaboard-2-home-lab/bare-metal

# Run the installation script
sudo bash install.sh
```

The script will:
1. Install AdGuard Home using the official installation script
2. Install Samba via `apt`
3. Copy the pre-configured `smb.conf` from `configs/samba/smb.conf`
4. Enable and start services (AdGuardHome, smbd, nmbd)
5. Optionally create a Samba user for authenticated access

**Follow the prompts** in the installation script.

### Step 4.2: Configure Docker Hybrid Services

After the bare-metal installation completes, configure the Docker services:

```bash
# Make sure you're in the bare-metal directory
cd ~/zimaboard-2-home-lab/bare-metal

# Copy the hybrid environment file
cp .env.hybrid.example .env.hybrid

# Edit the configuration
nano .env.hybrid
```

**Required Configuration Changes:**

```bash
# Your ZimaBoard's IP address
SERVER_IP=192.168.8.2

# Your timezone
TIMEZONE=America/New_York

# HDD path for Lancache (SSD path is already configured in Samba)
DATA_PATH_HDD=/mnt/hdd

# Optional: Adjust cache size
LANCACHE_MAX_SIZE=400
```

Save and exit.

### Step 4.3: Deploy Hybrid Docker Services

```bash
# Start Lancache and optional services
docker compose -f docker-compose.hybrid.yml --env-file .env.hybrid up -d

# Verify services are running
docker compose -f docker-compose.hybrid.yml ps

# View logs
docker compose -f docker-compose.hybrid.yml logs -f
```

**Expected Output:**

```
NAME                IMAGE                              STATUS
lancache            lancachenet/monolithic:latest      Up 10 seconds
```

### Step 4.4: Verify Services

```bash
# Check AdGuard Home (bare-metal)
sudo systemctl status AdGuardHome
curl http://192.168.8.2:3000

# Check Samba (bare-metal)
sudo systemctl status smbd nmbd
smbclient -L localhost -N

# Check Lancache (Docker)
docker compose -f docker-compose.hybrid.yml logs lancache
```

**✅ Path B Deployment Complete!**

Continue to [Section 5: Post-Installation Configuration](#️-section-5-post-installation-configuration-common-to-both-paths) for next steps.

---

## ⚙️ Section 5: Post-Installation Configuration (Common to Both Paths)

These steps apply to **both Path A and Path B** after deployment.

### Step 5.1: Configure AdGuard Home

#### Initial Setup Wizard

**✅ Good News**: This repository includes a **pre-configured `AdGuardHome.yaml`** that already binds to `0.0.0.0` (all interfaces), solving the common issue where the web wizard doesn't allow selecting this option.

1. **Open your web browser**
2. **Navigate to**: `http://192.168.8.2:3000` (replace with your actual server IP)
3. **Follow the initial setup wizard**:
   
   **📝 Note About Binding Configuration:**
   
   The configuration file already has the correct settings:
   - **Admin Web Interface**: Already bound to `0.0.0.0:3000` (all interfaces)
   - **DNS Server**: Already bound to `0.0.0.0:53` (all interfaces)
   
   You just need to:
   - **Create admin username and password** (save these!)
   - Click "Next" and "Open Dashboard"
   
   **Why pre-configured?** The AdGuard Home web interface setup wizard has a limitation - it doesn't provide an option to manually enter `0.0.0.0` for binding. It only shows specific interface IPs like `127.0.0.1`, `172.20.0.2`, etc. By providing a pre-configured file, we bypass this limitation.
   
   **Why 0.0.0.0?** Binding to `0.0.0.0` means listening on all network interfaces, making AdGuard Home accessible from:
   - The host machine (192.168.8.2)
   - Other devices on your network
   - Inside the Docker container (for containerized installations)
   - Maximum flexibility for different network configurations

#### Configure Upstream DNS

**✅ Already Configured**: The pre-configured file includes these upstream DNS servers:
- Cloudflare: 1.1.1.1, 1.0.0.1
- Google: 8.8.8.8, 8.8.4.4

You can optionally customize these:

1. Log into AdGuard Home dashboard
2. Go to **Settings → DNS settings**
3. View or modify the "Upstream DNS servers" field
4. Enable "Parallel requests" for faster resolution (if not already enabled)
5. Click "Save"

#### Add DNS Blocklists

**✅ Basic Lists Included**: The pre-configured file already includes:
- AdGuard DNS filter
- AdAway Default Blocklist

To enhance ad blocking further:

1. Go to **Filters → DNS blocklists**
2. You'll see the pre-configured lists are already active
3. Click "Add blocklist" to add these recommended additional lists:

**General Ad Blocking:**
```
https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt (already included)
https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt (already included)
```

**Additional Protection:**
```
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt
```

3. Click "Save"

#### 🎬 Attempting to Block Streaming Ads

**⚠️⚠️⚠️ CRITICAL WARNING ABOUT STREAMING AD BLOCKING ⚠️⚠️⚠️**

Blocking ads on streaming services (Netflix, Hulu, HBO Max, Peacock, YouTube, etc.) is **EXTREMELY DIFFICULT AND UNRELIABLE**. Here's why:

- **Same-Domain Serving**: Streaming services intentionally serve ads from the same domains as content
- **Active Countermeasures**: Services actively detect and circumvent ad blocking
- **Frequent Changes**: Ad delivery methods change constantly
- **Potential Breakage**: Blocking attempts **WILL BREAK** video playback entirely
- **App vs Browser**: Mobile apps are harder to block than web browsers
- **Limited Effectiveness**: Even with the best filters, success rates are **20-40% at best**
- **Terms of Service**: May violate service terms and risk account suspension

**The Reality:**
- YouTube ads: Very difficult, often breaks playback
- Netflix ads: Nearly impossible without breaking service
- Hulu ads: Extremely difficult, high breakage risk
- Cable/Live TV apps: Almost never works

**If you still want to try (at your own risk):**

1. Go to **Filters → DNS blocklists** → "Add blocklist"
2. Add these **experimental** lists:

```
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/fake.txt
https://blocklistproject.github.io/Lists/ads.txt
```

3. Go to **Filters → Custom filtering rules**
4. Add these regex patterns (**use with extreme caution**):

```
||doubleclick.net^
||googlesyndication.com^
||googleadservices.com^
||youtube.com/api/stats/ads^
||youtube.com/ptracking^
```

**Recommended Approach Instead:**

- Use browser extensions like **uBlock Origin** for web-based streaming
- Consider **YouTube Premium** for ad-free YouTube
- Accept that DNS-level blocking **cannot** effectively block streaming ads
- Focus on blocking tracking and malware instead

**If streaming services break:**
1. Go to **Settings → DNS settings**
2. Add the broken domain to the "DNS allowlist"
3. Or temporarily disable AdGuard Home:
   - **Path A**: `docker compose stop adguardhome`
   - **Path B**: `sudo systemctl stop AdGuardHome`

### Step 5.2: Verify Lancache Integration with AdGuard Home

**✅ LANCACHE DNS REWRITES ARE PRE-CONFIGURED!**

Good news! The `AdGuardHome.yaml` configuration file in this repository already includes DNS rewrites for all major gaming and content delivery services. **You don't need to manually configure DNS rewrites** - Lancache will work immediately after deployment.

#### Pre-Configured Services

The following services are already configured to use your Lancache server (default IP: `192.168.8.2`):

| Service | Domain Pattern |
|---------|----------------|
| **Steam** | `*.steamcontent.com` |
| **Epic Games** | `*.download.epicgames.com` |
| **Origin (EA)** | `*.origin.com` |
| **Xbox Live** | `*.xboxlive.com` |
| **PlayStation Network** | `*.playstation.net` |
| **Battle.net (Blizzard)** | `*.blizzard.com` |
| **Windows Updates** | `*.windowsupdate.com` |

#### Verify DNS Rewrites Are Active

1. **Via Web Interface**:
   - Log into AdGuard Home at `http://192.168.8.2:3000`
   - Go to **Filters → DNS rewrites**
   - You should see all 7 pre-configured rewrites listed

2. **Via Command Line**:
   ```bash
   # Test DNS resolution for a Lancache domain
   nslookup steamcontent.com 192.168.8.2
   
   # Expected output should show your server IP (e.g., 192.168.8.2)
   # If you see "No answer", check the troubleshooting steps below
   ```

#### Important: Update Server IP If Different

⚠️ **If your server IP is different from `192.168.8.2`**, you must update the DNS rewrites before starting AdGuard Home:

1. Edit the configuration file:
   ```bash
   nano configs/adguardhome/AdGuardHome.yaml
   ```

2. Find the `dns.rewrites` section (around line 148)

3. Replace all instances of `192.168.8.2` with your actual server IP

4. Save and start/restart AdGuard Home

#### Verify Lancache is Working

After starting the services and verifying DNS rewrites are active:

```bash
# For Path A:
docker compose logs -f lancache

# For Path B:
docker compose -f bare-metal/docker-compose.hybrid.yml logs -f lancache

# When downloading a game, you should see cache HIT/MISS entries
# First download: MISS (content is being cached)
# Subsequent downloads: HIT (served from cache)
```

### Step 5.3: Configure Your Router (GL.iNet x3000)

Configure your router to use AdGuard Home as the DNS server for all devices:

1. **Log into your x3000 router**:
   - Open browser: `http://192.168.8.1` (or your router's IP)
   - Enter admin credentials

2. **Navigate to Network Settings**:
   - Click on **Network** → **LAN**

3. **Configure DHCP DNS**:
   - Find "DHCP Server" settings
   - Set **Primary DNS**: `192.168.8.2` (your ZimaBoard)
   - Set **Secondary DNS**: `1.1.1.1` (fallback)
   - Click "Save" or "Apply"

4. **Renew DHCP on client devices**:
   - **Windows**: Open CMD as admin: `ipconfig /release && ipconfig /renew`
   - **macOS**: System Preferences → Network → Advanced → TCP/IP → Renew DHCP Lease
   - **Linux**: `sudo dhclient -r && sudo dhclient`
   - **Mobile**: Turn WiFi off and back on

5. **Verify DNS is working**:
   - On a client device, open browser
   - Go to: `http://192.168.8.2:3000`
   - Check AdGuard Home dashboard for queries
   - Try visiting a known ad-heavy website

### Step 5.4: Access Samba File Share

#### From Windows

1. Open **File Explorer**
2. In the address bar, type: `\\192.168.8.2\Shared`
3. Press Enter
4. The shared folder should open (guest access enabled by default)

**To map as network drive:**
- Right-click on "This PC" → "Map network drive"
- Drive letter: Choose available letter (e.g., Z:)
- Folder: `\\192.168.8.2\Shared`
- Check "Reconnect at sign-in"
- Click "Finish"

#### From macOS

1. Open **Finder**
2. Press `Cmd + K` (or Go → Connect to Server)
3. Enter: `smb://192.168.8.2/Shared`
4. Click "Connect"
5. Select "Guest" (or enter credentials if configured)
6. The shared folder will appear in Finder

#### From Linux

**Temporary Mount:**
```bash
# Install cifs-utils if not installed
sudo apt install -y cifs-utils

# Create mount point
mkdir -p ~/Shared

# Mount the share
sudo mount -t cifs //192.168.8.2/Shared ~/Shared -o guest,uid=$(id -u),gid=$(id -g)
```

**Permanent Mount (fstab):**
```bash
sudo nano /etc/fstab
```

Add this line:
```
//192.168.8.2/Shared  /home/yourusername/Shared  cifs  guest,uid=1000,gid=1000,nofail  0  0
```

Then mount:
```bash
sudo mount -a
```

**✅ Post-Installation Configuration Complete!**

Your homelab is now fully operational!

---

## 🔧 Section 6: How to Enable Optional Services

Both installation paths support optional services: **Uptime Kuma** (monitoring) and **CrowdSec** (security).

### For Path A (Fully Containerized)

#### Enable Uptime Kuma

1. Edit `docker-compose.yml`:
   ```bash
   cd ~/zimaboard-2-home-lab
   nano docker-compose.yml
   ```

2. Find the commented-out `uptime-kuma` section (around line 158)

3. Uncomment the entire section:
   - Remove the `#` from the beginning of each line in the section
   - Be careful to maintain proper indentation (YAML is sensitive to indentation)

4. Save and exit (Ctrl+X, Y, Enter)

5. Create data directory:
   ```bash
   mkdir -p ./data/uptime-kuma
   ```

6. Restart services:
   ```bash
   docker compose up -d
   ```

7. Access Uptime Kuma:
   - Open browser: `http://192.168.8.2:3001`
   - Create admin account
   - Add monitors for your services

**Example Monitors to Add:**
- **AdGuard Home**: HTTP(s) monitor to `http://192.168.8.2:3000`
- **Samba Share**: Ping monitor to `192.168.8.2` port 445
- **Lancache**: HTTP(s) monitor to `http://192.168.8.2:80`
- **Router**: Ping monitor to `192.168.8.1`
- **Internet**: Ping monitor to `8.8.8.8`

#### Enable CrowdSec

1. Edit `docker-compose.yml`:
   ```bash
   nano docker-compose.yml
   ```

2. Find the commented-out `crowdsec` section (around line 189)

3. Uncomment the entire section (remove `#` from each line)

4. Save and exit

5. Create data directories:
   ```bash
   mkdir -p ./data/crowdsec/config
   mkdir -p ./data/crowdsec/data
   ```

6. Deploy CrowdSec:
   ```bash
   docker compose up -d
   ```

7. Register with CrowdSec (optional but recommended):
   ```bash
   docker compose exec crowdsec cscli capi register
   ```

8. Install scenarios (collections of rules):
   ```bash
   docker compose exec crowdsec cscli collections install crowdsecurity/linux
   docker compose exec crowdsec cscli collections install crowdsecurity/sshd
   ```

9. Verify CrowdSec is running:
   ```bash
   docker compose exec crowdsec cscli metrics
   ```

### For Path B (Bare-Metal/Hybrid)

#### Enable Uptime Kuma

1. Edit `docker-compose.hybrid.yml`:
   ```bash
   cd ~/zimaboard-2-home-lab/bare-metal
   nano docker-compose.hybrid.yml
   ```

2. Find the commented-out `uptime-kuma` section

3. Uncomment the entire section (remove `#` from each line)

4. Save and exit

5. Create data directory:
   ```bash
   mkdir -p ./data/uptime-kuma
   ```

6. Restart services:
   ```bash
   docker compose -f docker-compose.hybrid.yml --env-file .env.hybrid up -d
   ```

7. Access Uptime Kuma:
   - Open browser: `http://192.168.8.2:3001`
   - Create admin account
   - Add monitors

#### Enable CrowdSec

1. Edit `docker-compose.hybrid.yml`:
   ```bash
   nano docker-compose.hybrid.yml
   ```

2. Find the commented-out `crowdsec` section

3. Uncomment the entire section

4. Save and exit

5. Create data directories:
   ```bash
   mkdir -p ./data/crowdsec/config
   mkdir -p ./data/crowdsec/data
   ```

6. Deploy:
   ```bash
   docker compose -f docker-compose.hybrid.yml --env-file .env.hybrid up -d
   ```

7. Configure as shown above for Path A

---

## 🔍 Monitoring and Maintenance

### View Service Status

**For Path A:**
```bash
cd ~/zimaboard-2-home-lab

# Check all services
docker compose ps

# View resource usage
docker stats

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f adguardhome
docker compose logs -f lancache
docker compose logs -f samba
```

**For Path B:**
```bash
# Check bare-metal services
sudo systemctl status AdGuardHome
sudo systemctl status smbd nmbd

# Check Docker services
cd ~/zimaboard-2-home-lab/bare-metal
docker compose -f docker-compose.hybrid.yml ps
docker compose -f docker-compose.hybrid.yml logs -f lancache
```

### Update Services

**For Path A:**
```bash
cd ~/zimaboard-2-home-lab

# Pull latest images
docker compose pull

# Restart services with new images
docker compose up -d

# Remove old images
docker image prune -f
```

**For Path B:**
```bash
# Update bare-metal services
sudo apt update && sudo apt upgrade -y

# Update AdGuard Home
# Visit https://github.com/AdguardTeam/AdGuardHome/releases for instructions

# Update Docker services
cd ~/zimaboard-2-home-lab/bare-metal
docker compose -f docker-compose.hybrid.yml pull
docker compose -f docker-compose.hybrid.yml up -d
docker image prune -f
```

### Backup Configuration

**For Path A:**
```bash
cd ~/zimaboard-2-home-lab

# Backup all configurations
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz \
  .env \
  docker-compose.yml \
  configs/ \
  data/adguardhome/ \
  data/uptime-kuma/

# Restore from backup
tar -xzf homelab-backup-YYYYMMDD.tar.gz
```

**For Path B:**
```bash
# Backup bare-metal configurations
sudo tar -czf baremet-backup-$(date +%Y%m%d).tar.gz \
  /etc/samba/smb.conf \
  /opt/AdGuardHome/AdGuardHome.yaml \
  ~/zimaboard-2-home-lab/bare-metal/

# Restore as needed
```

### Check Disk Usage

```bash
# Check overall disk usage
df -h

# Check Docker disk usage
docker system df

# Check specific mounts
du -sh /mnt/ssd/*
du -sh /mnt/hdd/*

# Check Lancache cache size
du -sh /mnt/hdd/lancache
```

### Troubleshooting

#### Port 53 Already in Use / AdGuard Home Won't Start

**Error Message:**
```
Error response from daemon: failed to bind host port for 0.0.0.0:53:172.20.0.2:53/tcp: address already in use
```

**Cause:** Ubuntu's `systemd-resolved` service is using port 53 for DNS resolution.

**Solution:**

1. **Stop and disable systemd-resolved:**
   ```bash
   sudo systemctl stop systemd-resolved
   sudo systemctl disable systemd-resolved
   ```

2. **Configure alternative DNS resolution:**
   ```bash
   # Remove the symlink
   sudo rm /etc/resolv.conf
   
   # Create new resolv.conf with Cloudflare DNS
   echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
   echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
   
   # Make immutable to prevent changes
   sudo chattr +i /etc/resolv.conf
   ```

3. **Verify port 53 is free:**
   ```bash
   sudo lsof -i :53
   # Should return nothing (port is free)
   ```

4. **Restart the container:**
   ```bash
   # Path A:
   docker compose up -d
   
   # Path B:
   sudo systemctl start AdGuardHome
   ```

**Alternative:** If you need systemd-resolved for other services, configure it to not listen on port 53:
```bash
sudo nano /etc/systemd/resolved.conf
# Add: DNSStubListener=no
sudo systemctl restart systemd-resolved
```

#### Cannot Access AdGuard Home Web Interface

**Symptoms:**
- Cannot reach `http://192.168.8.2:3000` after installation
- Browser shows "Connection refused" or "Unable to connect"
- AdGuard Home container/service is running but not accessible

**Cause:** AdGuard Home is not bound to the correct network interface.

**Solution:**

**NOTE**: This repository now includes a pre-configured `AdGuardHome.yaml` file that binds to `0.0.0.0` by default. If you're experiencing this issue, the config file may have been modified or replaced.

1. **For Path A (Docker):**
   
   a. Stop AdGuard Home:
   ```bash
   docker compose stop adguard
   ```
   
   b. Check the configuration file:
   ```bash
   cat ./configs/adguardhome/AdGuardHome.yaml | grep bind_host
   ```
   
   c. If `bind_host` is not `0.0.0.0`, restore the pre-configured file:
   ```bash
   # Backup your current config (if you have custom settings)
   cp ./configs/adguardhome/AdGuardHome.yaml ./configs/adguardhome/AdGuardHome.yaml.backup
   
   # Restore from git (this gets the pre-configured version)
   git checkout configs/adguardhome/AdGuardHome.yaml
   ```
   
   d. Or manually edit the file:
   ```bash
   nano ./configs/adguardhome/AdGuardHome.yaml
   ```
   
   Find and change:
   ```yaml
   bind_host: 0.0.0.0
   ```
   
   e. Start AdGuard Home again:
   ```bash
   docker compose up -d
   ```

2. **For Path B (Bare-Metal):**
   
   a. Stop AdGuard Home:
   ```bash
   sudo systemctl stop AdGuardHome
   ```
   
   b. Edit the configuration:
   ```bash
   sudo nano /opt/AdGuardHome/AdGuardHome.yaml
   ```
   
   c. Find the `bind_host` settings and change them to:
   ```yaml
   bind_host: 0.0.0.0
   ```
   
   Also check the DNS bind_hosts:
   ```yaml
   dns:
     bind_hosts:
       - 0.0.0.0
   ```
   
   d. Save and restart:
   ```bash
   sudo systemctl start AdGuardHome
   ```

3. **Verify the service is listening:**
   ```bash
   # Check if port 3000 is listening on all interfaces
   sudo netstat -tulpn | grep :3000
   # Should show: 0.0.0.0:3000
   
   # Or use ss command
   sudo ss -tulpn | grep :3000
   ```

4. **Check firewall (if enabled):**
   ```bash
   # Check if ufw is active
   sudo ufw status
   
   # If active, allow ports
   sudo ufw allow 3000/tcp
   sudo ufw allow 53/tcp
   sudo ufw allow 53/udp
   ```

#### AdGuard Home Not Blocking

**Path A:**
```bash
# Check if service is running
docker compose ps adguardhome

# Check logs for errors
docker compose logs adguardhome

# Restart service
docker compose restart adguardhome

# Test DNS resolution
nslookup doubleclick.net 192.168.8.2
# Should return 0.0.0.0 if blocked
```

**Path B:**
```bash
# Check if service is running
sudo systemctl status AdGuardHome

# Check logs
sudo journalctl -u AdGuardHome -n 50

# Restart service
sudo systemctl restart AdGuardHome

# Test DNS
nslookup doubleclick.net 192.168.8.2
```

#### Lancache Not Caching

```bash
# Check Lancache logs (both paths)
# Path A:
docker compose logs lancache | grep -i "cache"

# Path B:
cd ~/zimaboard-2-home-lab/bare-metal
docker compose -f docker-compose.hybrid.yml logs lancache | grep -i "cache"

# Verify DNS rewrites are configured in AdGuard Home
# Test resolution
nslookup steamcontent.com 192.168.8.2
# Should return your ZimaBoard IP (192.168.8.2)

# Check cache directory has proper permissions
ls -la /mnt/hdd/lancache
```

#### Samba Share Not Accessible

**Path A:**
```bash
# Check if service is running
docker compose ps samba

# Check logs
docker compose logs samba

# Test connection from ZimaBoard
smbclient -L localhost -N

# Check permissions on share directory
ls -la /mnt/ssd/fileshare
```

**Path B:**
```bash
# Check if service is running
sudo systemctl status smbd nmbd

# Check logs
sudo journalctl -u smbd -n 50
sudo journalctl -u nmbd -n 50

# Test Samba configuration
testparm

# Test connection
smbclient -L localhost -N

# Check permissions
ls -la /mnt/ssd/fileshare
```

#### Out of Disk Space

```bash
# Check disk usage
df -h

# Clear Lancache if needed
# Path A:
docker compose stop lancache
sudo rm -rf /mnt/hdd/lancache/*
docker compose start lancache

# Path B:
cd ~/zimaboard-2-home-lab/bare-metal
docker compose -f docker-compose.hybrid.yml stop lancache
sudo rm -rf /mnt/hdd/lancache/*
docker compose -f docker-compose.hybrid.yml start lancache

# Prune Docker resources
docker system prune -a --volumes
```

---

## 📊 Performance Expectations

With this setup running on your ZimaBoard 2, you can expect:

| Metric | Expected Performance |
|--------|---------------------|
| **DNS Response Time** | < 10ms (local) |
| **Cache Hit Rate** | 60-80% (after initial downloads) |
| **Bandwidth Savings** | 50-70% (for repeated downloads) |
| **Memory Usage** | 4-8GB total (all services) |
| **Samba Transfer Speed** | 100-200 MB/s (Gigabit limited) |
| **AdGuard Queries/sec** | 100-500 (typical home network) |

---

## 🛠️ Advanced Configuration

### Using Host Network Mode

For better DNS performance, you can run AdGuard Home in host network mode:

1. Edit `docker-compose.yml`
2. In the `adguard` service, change:
   ```yaml
   network_mode: host
   ```
3. Remove the `networks:` and `ports:` sections from the service
4. Restart: `docker compose up -d`

**Note:** This may cause port conflicts if other services use port 53.

### Custom Samba Configuration

To add authenticated access or additional shares:

1. Edit `configs/samba/smb.conf`
2. Modify or add share definitions
3. Restart Samba: `docker compose restart samba`

Example for authenticated access:
```ini
[Shared]
   path = /shares/Shared
   browseable = yes
   writable = yes
   guest ok = no
   valid users = yourusername
   create mask = 0644
   directory mask = 0755
```

### Adjust Lancache Size

Edit `.env` file:
```bash
# Increase cache size (in GB)
LANCACHE_MAX_SIZE=450
```

Restart services:
```bash
docker compose up -d
```

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

## 🙏 Acknowledgments

- **AdGuard Team** for AdGuard Home
- **Lancache.net** for the amazing game caching solution
- **Docker Community** for containerization tools
- **ZimaBoard** for excellent hardware

---

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review service logs: `docker compose logs`
3. Open an issue on GitHub with details
4. Check official documentation:
   - [AdGuard Home](https://github.com/AdguardTeam/AdguardHome)
   - [Lancache](https://lancache.net/)
   - [Docker Compose](https://docs.docker.com/compose/)

---

**🎉 Enjoy your ZimaBoard Homelab!**

