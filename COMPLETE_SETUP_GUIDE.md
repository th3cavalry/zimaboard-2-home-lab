# 🏠 ZimaBoard 2 Homelab Complete Installation & Configuration Guide

**The definitive guide for setting up your ZimaBoard 2 security homelab from scratch to production-ready**

---

## 📋 Table of Contents

- [Pre-Installation Setup](#-pre-installation-setup)
- [Hardware Configuration](#️-hardware-configuration)
- [Operating System Installation](#-operating-system-installation)
- [Homelab Software Installation](#-homelab-software-installation)
- [Post-Installation Configuration](#️-post-installation-configuration)
- [Service Management](#-service-management)
- [Security Hardening](#-security-hardening)
- [Maintenance & Updates](#-maintenance--updates)
- [Troubleshooting](#-troubleshooting)

---

## 🛠️ Pre-Installation Setup

### Hardware Requirements

**Minimum Requirements:**
- ZimaBoard 2 (Intel N100, 16GB RAM)
- 32GB eMMC (built-in)
- Network connection (Ethernet recommended)

**Recommended Setup:**
- ZimaBoard 2 with 16GB RAM
- 2TB SATA SSD for data storage
- Gigabit Ethernet connection
- UPS for power protection

### Network Planning

**IP Address Assignment:**
```bash
# Recommended static IP configuration
IP Address: 192.168.1.100/24  # Or your network range
Gateway: 192.168.1.1
DNS: 1.1.1.1, 8.8.8.8 (temporary, will use AdGuard later)
```

**Port Planning:**
- Port 80: Main dashboard (HTTP)
- Port 443: HTTPS (if SSL configured)
- Port 3000: AdGuard Home
- Port 8080: Nextcloud
- Port 19999: Netdata (optional)
- Port 22: SSH (secure access)

### Pre-Installation Checklist

- [ ] ZimaBoard 2 powered and connected to network
- [ ] SSD installed (if using external storage)
- [ ] Network configuration planned
- [ ] Installation media prepared
- [ ] Backup plan for existing data

---

## ⚙️ Hardware Configuration

### SSD Installation (Recommended)

1. **Power Down ZimaBoard 2**
   ```bash
   sudo shutdown -h now
   ```

2. **Install 2.5" SATA SSD**
   - Remove ZimaBoard 2 case
   - Connect SATA SSD to internal connector
   - Secure SSD in case
   - Reassemble unit

3. **Verify Detection After Boot**
   ```bash
   lsblk
   # Should show both eMMC and SSD
   ```

### BIOS Configuration

**Access BIOS:**
- Power on ZimaBoard 2
- Press `Delete` or `F2` during boot
- Navigate to configuration settings

**Important Settings:**
```
Virtualization Technology: Enabled
Secure Boot: Disabled (if issues occur)
Boot Priority: USB first (for installation)
Network Boot: Disabled (security)
```

---

## 💾 Operating System Installation

### Download Ubuntu Server

```bash
# Download Ubuntu Server 24.04 LTS
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# Verify checksum
sha256sum ubuntu-24.04-live-server-amd64.iso
```

### Create Installation Media

**Linux/macOS:**
```bash
# Replace /dev/sdX with your USB device
sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
sync
```

**Windows:**
- Use Rufus or Etcher
- Select ISO file and USB device
- Write to USB

### Ubuntu Server Installation

1. **Boot from USB**
   - Insert USB into ZimaBoard 2
   - Power on and boot from USB
   - Select "Install Ubuntu Server"

2. **Network Configuration**
   ```
   Configure network interface:
   - Use DHCP initially
   - Note assigned IP address
   - Plan static IP for later
   ```

3. **Disk Partitioning**
   ```
   Recommended layout:
   - eMMC: OS partition (use entire 64GB eMMC)
   - SSD: Will be configured by homelab installer
   ```

4. **User Account Setup**
   ```
   Username: th3cavalry (or your preference)
   Password: [Strong password]
   Install OpenSSH server: Yes
   Import SSH identity: No (configure later)
   ```

5. **Package Selection**
   ```
   Featured Server Snaps: None selected
   (Our installer will handle all packages)
   ```

### Initial System Update

```bash
# After first boot, update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop net-tools

# Check system info
hostnamectl
df -h
free -h
```

---

## 🚀 Homelab Software Installation

### Method 1: Quick Installation (Recommended)

**Single Command Installation:**
```bash
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
```

### Method 2: Manual Installation (If Quick Install Fails)

**Step-by-Step Manual Process:**

1. **Download Installation Files**
   ```bash
   # Create working directory
   mkdir -p ~/homelab-install
   cd ~/homelab-install
   
   # Download installer components
   wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh
   chmod +x install.sh
   ```

2. **Run Installation with Debug Mode**
   ```bash
   # Run with verbose output
   sudo bash -x ./install.sh
   ```

3. **If Installation Fails - Use Simple Fix**
   ```bash
   # Download simple fix script
   wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-fix.sh
   chmod +x simple-fix.sh
   sudo ./simple-fix.sh
   ```

### Installation Process Overview

**Phase 1: System Preparation**
- Updates package repositories
- Installs essential packages
- Configures firewall (UFW)
- Sets up fail2ban for security
- Optimizes system for eMMC longevity

**Phase 2: Storage Configuration**
- Detects available storage devices
- Configures SSD if present
- Sets up optimal directory structure
- Moves logs to SSD (reduces eMMC wear)

**Phase 3: AdGuard Home Installation**
- Downloads and installs AdGuard Home
- Configures DNS filtering
- Sets up web interface
- Configures blocklists

**Phase 4: Nextcloud Installation**
- Installs Nextcloud with SQLite
- Configures data storage on SSD
- Sets up web interface
- Creates admin account

**Phase 5: Nginx Web Server**
- Installs and configures Nginx
- Creates beautiful dashboard
- Sets up reverse proxy (optional)
- Configures SSL (if requested)

---

## ⚙️ Post-Installation Configuration

### Initial Access and Verification

1. **Find Your ZimaBoard IP Address**
   ```bash
   ip addr show | grep inet
   # Or check your router's DHCP client list
   ```

2. **Access Main Dashboard**
   ```
   URL: http://YOUR-ZIMABOARD-IP
   Should show: Beautiful homelab dashboard
   ```

3. **Verify All Services**
   ```bash
   # Check service status
   systemctl status nginx
   systemctl status AdGuardHome
   
   # Check if ports are open
   ss -tlnp | grep -E ':80|:3000|:8080'
   ```

### Service-Specific Configuration

#### AdGuard Home Setup

1. **Access AdGuard Home**
   ```
   URL: http://YOUR-IP:3000
   Default Login: admin / admin123
   ```

2. **Initial Configuration Wizard**
   - Set admin username and password
   - Configure listening interface: `0.0.0.0:3000`
   - DNS server: `0.0.0.0:53`
   - Enable web interface protection

3. **Configure DNS Settings**
   ```
   Upstream DNS servers:
   - Cloudflare: 1.1.1.1, 1.0.0.1
   - Quad9: 9.9.9.9, 149.112.112.112
   - Google: 8.8.8.8, 8.8.4.4
   
   Bootstrap DNS: 1.1.1.1, 8.8.8.8
   ```

4. **Enable Blocklists**
   ```
   Recommended lists:
   - AdGuard Default Blocking Filter
   - EasyList
   - Peter Lowe's Ad and tracking server list
   - Dan Pollock's hosts file
   ```

#### Nextcloud Setup

1. **Access Nextcloud**
   ```
   URL: http://YOUR-IP:8080
   Default Login: admin / admin123
   ```

2. **Complete Setup Wizard**
   - Change admin password immediately
   - Skip recommended apps (install as needed)
   - Configure data directory: `/mnt/ssd-data/nextcloud`

3. **Configure Trusted Domains**
   ```bash
   # SSH into ZimaBoard
   ssh th3cavalry@YOUR-IP
   
   # Add your IP as trusted domain
   sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="YOUR-IP"
   ```

4. **Install Recommended Apps**
   - Calendar
   - Contacts
   - Notes
   - Photos
   - Deck (Kanban boards)

### Network Configuration

#### Configure Static IP (Recommended)

1. **Find Network Interface Name**
   ```bash
   ip link show
   # Usually: eth0, enp1s0, or similar
   ```

2. **Configure Netplan**
   ```bash
   sudo nano /etc/netplan/00-installer-config.yaml
   ```
   
   ```yaml
   network:
     version: 2
     ethernets:
       eth0:  # Replace with your interface name
         addresses:
           - 192.168.1.100/24  # Your desired IP
         gateway4: 192.168.1.1    # Your router IP
         nameservers:
           addresses:
             - 127.0.0.1        # Use AdGuard Home
             - 1.1.1.1          # Fallback DNS
   ```

3. **Apply Configuration**
   ```bash
   sudo netplan apply
   ```

#### Configure Router DNS (Network-Wide Ad Blocking)

**Option 1: Router DNS Settings**
- Access your router admin panel
- Change DNS servers to: `192.168.1.100` (your ZimaBoard IP)
- This enables network-wide ad blocking

**Option 2: DHCP DNS Assignment**
- Configure router DHCP to provide ZimaBoard IP as DNS
- All devices will automatically use AdGuard Home

---

## 🔧 Service Management

### System Service Commands

```bash
# Check service status
sudo systemctl status nginx
sudo systemctl status AdGuardHome

# Start/stop services
sudo systemctl start nginx
sudo systemctl stop AdGuardHome
sudo systemctl restart nginx

# Enable/disable autostart
sudo systemctl enable AdGuardHome
sudo systemctl disable nginx

# View service logs
sudo journalctl -u nginx -f
sudo journalctl -u AdGuardHome --since "1 hour ago"
```

### Nextcloud Management

```bash
# Nextcloud CLI tool (occ)
cd /var/www/nextcloud
sudo -u www-data php occ

# Common commands
sudo -u www-data php occ status
sudo -u www-data php occ user:list
sudo -u www-data php occ maintenance:mode --on
sudo -u www-data php occ maintenance:mode --off

# Update Nextcloud
sudo -u www-data php occ upgrade
```

### Storage Management

```bash
# Check disk usage
df -h
du -sh /mnt/ssd-data/*

# Check SSD health
sudo smartctl -a /dev/sda

# Monitor disk I/O
sudo iotop
```

---

## 🔒 Security Hardening

### SSH Security

1. **Create SSH Key Pair (On your computer)**
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. **Copy Public Key to ZimaBoard**
   ```bash
   ssh-copy-id th3cavalry@YOUR-ZIMABOARD-IP
   ```

3. **Harden SSH Configuration**
   ```bash
   sudo nano /etc/ssh/sshd_config
   ```
   
   ```
   # Recommended settings
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   Port 2222  # Change default port
   MaxAuthTries 3
   ClientAliveInterval 300
   ```
   
   ```bash
   sudo systemctl restart ssh
   ```

### Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow essential services
sudo ufw allow 2222/tcp    # SSH (if changed port)
sudo ufw allow 80/tcp     # HTTP dashboard
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 3000/tcp   # AdGuard Home
sudo ufw allow 8080/tcp   # Nextcloud

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Fail2Ban Configuration

```bash
# Check fail2ban status
sudo fail2ban-client status

# View jail status
sudo fail2ban-client status sshd

# Unban IP if needed
sudo fail2ban-client set sshd unbanip YOUR-IP
```

### Regular Security Updates

```bash
# Create update script
sudo nano /usr/local/bin/security-update.sh
```

```bash
#!/bin/bash
# Security update script

echo "Starting security updates..."
apt update
apt upgrade -y
apt autoremove -y
apt autoclean

echo "Restarting services..."
systemctl restart nginx
systemctl restart AdGuardHome

echo "Security updates completed!"
```

```bash
sudo chmod +x /usr/local/bin/security-update.sh

# Schedule weekly updates
sudo crontab -e
# Add: 0 3 * * 0 /usr/local/bin/security-update.sh >> /var/log/security-updates.log 2>&1
```

---

## 🔄 Maintenance & Updates

### Daily Monitoring

```bash
# Create monitoring script
nano ~/check-homelab.sh
```

```bash
#!/bin/bash
# Homelab health check script

echo "=== ZimaBoard 2 Homelab Status ==="
echo "Date: $(date)"
echo

# System resources
echo "--- System Resources ---"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% usage"
echo "Memory: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
echo "Disk: $(df -h / | awk 'NR==2{print $5}')"
echo

# Service status
echo "--- Service Status ---"
systemctl is-active --quiet nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Down"
systemctl is-active --quiet AdGuardHome && echo "✅ AdGuard: Running" || echo "❌ AdGuard: Down"
curl -s http://localhost:8080 > /dev/null && echo "✅ Nextcloud: Responding" || echo "❌ Nextcloud: Not responding"

# Storage status
echo "--- Storage Status ---"
echo "SSD Data: $(df -h /mnt/ssd-data | awk 'NR==2{print $5}')"

# Network connectivity
echo "--- Network Status ---"
ping -c 1 1.1.1.1 > /dev/null && echo "✅ Internet: Connected" || echo "❌ Internet: Disconnected"

echo "=== End Status Report ==="
```

```bash
chmod +x ~/check-homelab.sh
```

### Weekly Maintenance Tasks

1. **Update System Packages**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Check AdGuard Home Logs**
   ```bash
   # Review blocked queries
   sudo journalctl -u AdGuardHome --since "7 days ago" | grep -i blocked
   ```

3. **Monitor Nextcloud**
   ```bash
   # Check Nextcloud logs
   sudo tail -f /var/www/nextcloud/data/nextcloud.log
   ```

4. **Backup Important Data**
   ```bash
   # Create backup script
   sudo nano /usr/local/bin/backup-homelab.sh
   ```

### Monthly Updates

1. **Update Nextcloud**
   ```bash
   cd /var/www/nextcloud
   sudo -u www-data php occ upgrade
   ```

2. **Update AdGuard Home**
   ```bash
   # AdGuard Home auto-updates, but check version
   curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep tag_name
   ```

3. **Review System Logs**
   ```bash
   sudo journalctl --since "30 days ago" | grep -E "error|warning|critical"
   ```

---

## 🚨 Troubleshooting

### Common Installation Issues

#### Issue: "curl: command not found"
**Solution:**
```bash
sudo apt update
sudo apt install curl -y
```

#### Issue: "Permission denied" during installation
**Solution:**
```bash
# Ensure you're using sudo
sudo curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
```

#### Issue: SSD not detected
**Solution:**
```bash
# Check if SSD is connected properly
lsblk
sudo fdisk -l

# If SSD shows but not mounted
sudo mount /dev/sda1 /mnt/ssd-data
```

### Service-Specific Issues

#### AdGuard Home Won't Start
**Diagnosis:**
```bash
sudo systemctl status AdGuardHome
sudo journalctl -u AdGuardHome -n 50
```

**Common Solutions:**
```bash
# Port 53 conflict with systemd-resolved
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Restart AdGuard Home
sudo systemctl restart AdGuardHome
```

#### Nextcloud Access Issues
**Diagnosis:**
```bash
# Check if service is running
curl -I http://localhost:8080

# Check PHP-FPM status
sudo systemctl status php8.3-fpm
```

**Solutions:**
```bash
# Fix permissions
sudo chown -R www-data:www-data /var/www/nextcloud
sudo chmod -R 755 /var/www/nextcloud

# Restart services
sudo systemctl restart nginx php8.3-fpm
```

#### Dashboard Not Loading
**Diagnosis:**
```bash
# Check nginx status
sudo systemctl status nginx
sudo nginx -t

# Check if port 80 is occupied
sudo ss -tlnp | grep :80
```

**Solutions:**
```bash
# Fix nginx configuration
sudo nginx -t  # Check for errors
sudo systemctl restart nginx

# Check dashboard file
ls -la /var/www/html/index.html
```

### Network Issues

#### Can't Access Services Remotely
**Checklist:**
1. Firewall configuration
   ```bash
   sudo ufw status
   ```

2. Service binding
   ```bash
   sudo ss -tlnp | grep -E ':80|:3000|:8080'
   ```

3. Network connectivity
   ```bash
   ping YOUR-ZIMABOARD-IP
   ```

#### DNS Not Working
**Solutions:**
```bash
# Check AdGuard Home status
curl http://localhost:3000

# Test DNS resolution
nslookup google.com 127.0.0.1

# Check if port 53 is available
sudo ss -tlnp | grep :53
```

### Performance Issues

#### High CPU Usage
**Diagnosis:**
```bash
htop
sudo iotop
```

**Solutions:**
```bash
# Limit Nextcloud background jobs
sudo -u www-data php /var/www/nextcloud/occ config:app:set files_external files_external_allow_create_new --value="no"

# Optimize database
sudo -u www-data php /var/www/nextcloud/occ db:add-missing-indices
```

#### Storage Full
**Solutions:**
```bash
# Clean up logs
sudo journalctl --vacuum-size=100M

# Clean Nextcloud trash
sudo -u www-data php /var/www/nextcloud/occ trashbin:cleanup --all-users

# Clean system cache
sudo apt autoremove -y
sudo apt autoclean
```

---

## 📞 Getting Help

### Log Collection for Support

```bash
# Create support bundle
mkdir ~/homelab-support
cd ~/homelab-support

# System information
hostnamectl > system-info.txt
free -h > memory-info.txt
df -h > disk-info.txt
lsblk > block-devices.txt

# Service logs
sudo journalctl -u nginx --since "24 hours ago" > nginx.log
sudo journalctl -u AdGuardHome --since "24 hours ago" > adguard.log

# Configuration files (remove sensitive data)
mkdir nginx-config
sudo cp /etc/nginx/sites-available/* nginx-config/ 2>/dev/null || true
sudo cp /opt/AdGuardHome/AdGuardHome.yaml adguard-config.yaml 2>/dev/null || true

# Network information
ip addr show > network-interfaces.txt
sudo ufw status verbose > firewall-status.txt

echo "Support bundle created in ~/homelab-support/"
```

### Community Resources

- **GitHub Issues**: [Report bugs and issues](https://github.com/th3cavalry/zimaboard-2-home-lab/issues)
- **AdGuard Home Docs**: [Official documentation](https://adguard.com/kb/adguard-home/)
- **Nextcloud Admin Manual**: [Administration guide](https://docs.nextcloud.com/server/stable/admin_manual/)
- **Ubuntu Server Guide**: [Official Ubuntu documentation](https://ubuntu.com/server/docs)

---

## 🎉 Conclusion

Congratulations! You now have a fully functional ZimaBoard 2 homelab with:

- ✅ **Network-wide ad blocking** with AdGuard Home
- ✅ **Personal cloud storage** with Nextcloud
- ✅ **Beautiful web dashboard** for easy access
- ✅ **Security hardening** and monitoring
- ✅ **Automated maintenance** capabilities

Your homelab is ready to provide enhanced privacy, security, and convenience for your home network. Remember to:

1. **Change all default passwords immediately**
2. **Configure regular backups**
3. **Monitor system health regularly**
4. **Keep all services updated**
5. **Review security logs periodically**

**Happy homelabbing! 🏠🔒🚀**
