# 🏠 ZimaBoard Homelab Services

**A complete, production-ready containerized homelab solution optimized for ZimaBoard 2 hardware**

[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![Ubuntu Server](https://img.shields.io/badge/Ubuntu-Server%2022.04%20LTS-orange)](https://ubuntu.com/server)
[![ZimaBoard 2](https://img.shields.io/badge/ZimaBoard-2%20Supported-blue)](https://www.zimaspace.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 📋 Introduction

This repository provides a complete Docker-based homelab configuration specifically designed for the ZimaBoard 2 hardware platform. It includes network-wide ad blocking, game download caching, and network file storage—all optimized for cellular broadband environments.

### What You Get

- **🛡️ AdGuard Home**: Network-wide ad blocking and DNS security
- **⚡ Lancache**: Gaming and software download cache (Steam, Epic Games, etc.)
- **📁 Samba**: Simple, high-performance network file storage (1TB)
- **📊 Optional Monitoring**: Uptime Kuma for service health tracking
- **🔒 Optional Security**: CrowdSec for intrusion prevention

### Why This Setup?

- **Bandwidth Optimized**: Cache downloads to reduce cellular data usage
- **Hardware Optimized**: Efficient use of your 16GB RAM and multi-drive setup
- **Container-Based**: Easy deployment, updates, and management with Docker
- **Production Ready**: Complete documentation for both automated and manual setup

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
  - Configured with WAN port reconfigured as LAN port
  - ZimaBoard connected via both NICs to LAN ports
  - Cellular broadband internet connection

### Network Configuration
- **ZimaBoard Static IP**: 192.168.8.2 (preconfigured)
- **All client devices**: Connected wirelessly to x3000
- **ZimaBoard**: Only hardwired device on network

---

## 🗂️ Repository Structure

```
zimaboard-homelab-services/
├── .env.example                    # Environment configuration template
├── docker-compose.yml              # Main Docker Compose configuration
├── README.md                       # This file
├── configs/                        # Service configurations
│   ├── adguardhome/
│   │   └── README.md              # AdGuard Home config placeholder
│   ├── lancache/
│   │   └── README.md              # Lancache config placeholder
│   └── samba/
│       └── smb.conf               # Pre-configured Samba configuration
└── data/                          # Persistent data directories
    ├── adguardhome/
    │   └── README.md              # AdGuard Home data placeholder
    └── fileshare/
        └── README.md              # Samba share mount point
```

---

## 🚀 Part 1: Host (ZimaBoard) Preparation

This section covers the manual setup of your ZimaBoard 2 before deploying Docker services.

### Step 1: Install Base Operating System

This guide assumes you have **Ubuntu Server 22.04 LTS** installed on your ZimaBoard 2's 64GB eMMC storage.

**Installation Notes:**
- Download Ubuntu Server 22.04 LTS from [ubuntu.com/download/server](https://ubuntu.com/download/server)
- Create a bootable USB drive using [Rufus](https://rufus.ie/) (Windows) or `dd` (Linux/Mac)
- Boot ZimaBoard from USB and follow the installation wizard
- Configure network settings to use static IP: 192.168.8.2
- Create an admin user account during installation

### Step 2: Install Docker and Docker Compose

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

### Step 3: Prepare Storage (Critical Step)

This step prepares your 2TB SSD and 500GB HDD for use with the homelab services.

#### Identify Your Drives

```bash
# List all block devices
lsblk

# Example output:
# NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
# sda      8:0    0   1.8T  0 disk           <- Your 2TB SSD
# sdb      8:16   0 465.8G  0 disk           <- Your 500GB HDD
# mmcblk0  179:0  0  59.6G  0 disk           <- Your 64GB eMMC (OS)
# ├─mmcblk0p1 179:1  0     1G  0 part /boot/efi
# └─mmcblk0p2 179:2  0  58.6G  0 part /

# Check if drives are already formatted
sudo fdisk -l /dev/sda
sudo fdisk -l /dev/sdb
```

#### Format the Drives (CAUTION: This erases all data!)

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

#### Create Mount Points

```bash
# Create mount point directories
sudo mkdir -p /mnt/ssd
sudo mkdir -p /mnt/hdd

# Set ownership
sudo chown -R $USER:$USER /mnt/ssd /mnt/hdd
```

#### Configure Automatic Mounting (fstab)

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

#### Create Service Data Directories

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

---

## 🚀 Part 2: Automated Deployment

Now that your ZimaBoard is prepared, deploy the homelab services.

### Step 1: Clone the Repository

```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/th3cavalry/zimaboard-2-home-lab.git
cd zimaboard-2-home-lab
```

### Step 2: Configure Environment Variables

```bash
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

# Storage paths (should match what you created)
DATA_PATH_SSD=/mnt/ssd
DATA_PATH_HDD=/mnt/hdd

# Optional: Adjust cache size based on available space (in GB)
LANCACHE_MAX_SIZE=400
```

Save and exit (Ctrl+X, then Y, then Enter).

### Step 3: Deploy Services

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

### Step 4: Verify Service Health

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

---

## ⚙️ Part 3: Post-Install Configuration

### AdGuard Home Setup

#### Access the Web Interface

1. Open your web browser
2. Navigate to: `http://192.168.8.2:3000`
3. Follow the initial setup wizard:
   - **Admin Web Interface**: Port 3000 (already set)
   - **DNS Server**: Port 53 (already set)
   - **Create admin username and password** (save these!)
   - Click "Next" and "Open Dashboard"

#### Configure Upstream DNS

1. Go to **Settings → DNS settings**
2. In the "Upstream DNS servers" field, add:
   ```
   1.1.1.1
   1.0.0.1
   8.8.8.8
   8.8.4.4
   ```
3. Enable "Parallel requests" for faster resolution
4. Click "Save"

#### Add DNS Blocklists

AdGuard Home comes with basic filters. To enhance ad blocking:

1. Go to **Filters → DNS blocklists**
2. Click "Add blocklist" and add these recommended lists:

**General Ad Blocking:**
```
https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
```

**Additional Protection:**
```
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt
```

3. Click "Save"

#### 🎬 Attempting to Block Streaming Ads

**⚠️ IMPORTANT WARNING ABOUT STREAMING AD BLOCKING:**

Blocking ads on streaming services (Netflix, Hulu, HBO Max, Peacock, YouTube, etc.) is **extremely difficult and unreliable**. Here's why:

- **Same-Domain Serving**: Streaming services intentionally serve ads from the same domains as content
- **Active Countermeasures**: Services actively detect and circumvent ad blocking
- **Frequent Changes**: Ad delivery methods change constantly
- **Potential Breakage**: Blocking attempts can break video playback entirely
- **App vs Browser**: Mobile apps are harder to block than web browsers
- **Limited Effectiveness**: Even with the best filters, success rates are 20-40% at best

**If you still want to try:**

1. Go to **Filters → DNS blocklists** → "Add blocklist"
2. Add these **experimental** lists:

```
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/fake.txt
https://blocklistproject.github.io/Lists/ads.txt
```

3. Go to **Filters → Custom filtering rules**
4. Add these regex patterns (use with caution):

```
||doubleclick.net^
||googlesyndication.com^
||googleadservices.com^
||youtube.com/api/stats/ads^
||youtube.com/ptracking^
```

**Recommended Approach:**

Instead of relying solely on DNS blocking for streaming ads:
- Use browser extensions like uBlock Origin for web-based streaming
- Consider YouTube Premium for ad-free YouTube
- Use Pi-hole's Regex blocking as a secondary layer
- Accept that some ads will get through

**If streaming services break:**
1. Go to **Settings → DNS settings**
2. Add the broken domain to the "DNS allowlist"
3. Or temporarily disable AdGuard Home: `docker compose stop adguardhome`

### Lancache Integration with AdGuard Home

Lancache works by intercepting requests for game content and serving them from your local cache. You need to configure DNS rewrites in AdGuard Home to redirect gaming traffic to Lancache.

#### Configure DNS Rewrites

1. In AdGuard Home, go to **Filters → DNS rewrites**
2. Click "Add DNS rewrite"
3. Add the following entries (one at a time):

**Steam:**
```
Domain: *.steamcontent.com
Answer: 192.168.8.2
```

**Epic Games:**
```
Domain: *.download.epicgames.com
Answer: 192.168.8.2
```

**Origin (EA):**
```
Domain: *.origin.com
Answer: 192.168.8.2
```

**Xbox Live:**
```
Domain: *.xboxlive.com
Answer: 192.168.8.2
```

**PlayStation Network:**
```
Domain: *.playstation.net
Answer: 192.168.8.2
```

**Battle.net (Blizzard):**
```
Domain: *.blizzard.com
Answer: 192.168.8.2
```

**Windows Updates:**
```
Domain: *.windowsupdate.com
Answer: 192.168.8.2
```

**Note:** Make sure to use your actual ZimaBoard IP (192.168.8.2) in the "Answer" field.

#### Verify Lancache is Working

After configuring DNS rewrites:

```bash
# Check Lancache logs
docker compose logs -f lancache

# When downloading a game, you should see cache HIT/MISS entries
# First download: MISS (cached)
# Subsequent downloads: HIT (served from cache)
```

### Router Configuration (GL.iNet x3000)

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
   - **Windows**: `ipconfig /release && ipconfig /renew`
   - **macOS**: System Preferences → Network → Advanced → TCP/IP → Renew DHCP Lease
   - **Linux**: `sudo dhclient -r && sudo dhclient`
   - **Mobile**: Turn WiFi off and back on

5. **Verify DNS is working**:
   - On a client device, open browser
   - Go to: `http://192.168.8.2:3000`
   - Check AdGuard Home dashboard for queries

### Samba File Share Access

#### Access from Windows

1. Open **File Explorer**
2. In the address bar, type: `\\192.168.8.2\Shared`
3. Press Enter
4. The shared folder should open (guest access enabled)
5. To map as network drive:
   - Right-click on "This PC" → "Map network drive"
   - Drive letter: Choose available letter (e.g., Z:)
   - Folder: `\\192.168.8.2\Shared`
   - Check "Reconnect at sign-in"
   - Click "Finish"

#### Access from macOS

1. Open **Finder**
2. Press `Cmd + K` (or Go → Connect to Server)
3. Enter: `smb://192.168.8.2/Shared`
4. Click "Connect"
5. Select "Guest" (or enter credentials if configured)
6. The shared folder will appear in Finder

#### Access from Linux

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

---

## 🔧 Part 4: Optional Services

### Uptime Kuma (Network Monitoring)

Uptime Kuma provides a beautiful dashboard to monitor all your services.

#### Enable Uptime Kuma

1. Edit `docker-compose.yml`:
   ```bash
   nano docker-compose.yml
   ```

2. Find the commented-out `uptime-kuma` section (around line 175)

3. Uncomment the entire section:
   - Remove the `#` from the beginning of each line in the section
   - Be careful to maintain proper indentation

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

#### Example Monitors to Add

- **AdGuard Home**: HTTP(s) monitor to `http://192.168.8.2:3000`
- **Samba Share**: Ping monitor to `192.168.8.2` port 445
- **Lancache**: HTTP(s) monitor to `http://192.168.8.2:8080`
- **Router**: Ping monitor to `192.168.8.1`
- **Internet**: Ping monitor to `8.8.8.8`

### CrowdSec (Intrusion Prevention)

CrowdSec is a modern, collaborative IPS that protects your services.

#### Enable CrowdSec

1. Edit `docker-compose.yml`:
   ```bash
   nano docker-compose.yml
   ```

2. Find the commented-out `crowdsec` section (around line 210)

3. Uncomment the entire section:
   - Remove the `#` from the beginning of each line
   - Maintain proper indentation

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

---

## 🔍 Monitoring and Maintenance

### View Service Status

```bash
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

### Update Services

```bash
# Pull latest images
docker compose pull

# Restart services with new images
docker compose up -d

# Remove old images
docker image prune -f
```

### Backup Configuration

```bash
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

#### AdGuard Home Not Blocking

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

#### Lancache Not Caching

```bash
# Check Lancache logs
docker compose logs lancache | grep -i "cache"

# Verify DNS rewrites are configured in AdGuard Home
# Test resolution
nslookup steamcontent.com 192.168.8.2
# Should return your ZimaBoard IP (192.168.8.2)

# Check cache directory has proper permissions
ls -la /mnt/hdd/lancache
```

#### Samba Share Not Accessible

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

#### Out of Disk Space

```bash
# Check disk usage
df -h

# Clear Lancache if needed
docker compose stop lancache
sudo rm -rf /mnt/hdd/lancache/*
docker compose start lancache

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

