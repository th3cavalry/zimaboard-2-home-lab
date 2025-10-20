# Pi-hole Alternative Installation Guide

## 🔄 Overview

By default, this homelab uses **AdGuard Home** as the DNS filtering and ad-blocking solution. However, if you prefer **Pi-hole**, you can use this guide to install Pi-hole instead.

**Why AdGuard Home is the default:**
- ✅ Modern, responsive web interface
- ✅ Built-in DNS-over-HTTPS support
- ✅ No port conflicts (uses port 3000 instead of port 80)
- ✅ Better mobile apps and management
- ✅ Per-client settings and parental controls

**Why you might prefer Pi-hole:**
- ✅ Larger community and more documentation
- ✅ More mature blocklist ecosystem
- ✅ Extensive third-party tools and integrations
- ✅ Web interface uses standard port 80 (if you prefer this)

---

## 📋 Option 1: Fresh Install with Pi-hole

If you haven't installed the homelab yet, you can modify the installation script to use Pi-hole:

### Step 1: Download the Installation Script

```bash
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/ubuntu-homelab-simple.sh
chmod +x ubuntu-homelab-simple.sh
```

### Step 2: Edit the Script

Open the script in your favorite editor:

```bash
nano ubuntu-homelab-simple.sh
```

### Step 3: Replace AdGuard Home with Pi-hole

Find the AdGuard Home installation section (around line 382) and replace it with:

```bash
# 6. Install Pi-hole
print_status "🔥 Installing Pi-hole..."

# Install Pi-hole dependencies
apt-get install -y curl

# Set up automated Pi-hole installation
mkdir -p /etc/pihole
cat > /etc/pihole/setupVars.conf << PIHOLE_SETUP
WEBPASSWORD=
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=192.168.8.2/24
IPV6_ADDRESS=
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=8.8.8.8
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
BLOCKING_ENABLED=true
PIHOLE_SETUP

# Install Pi-hole
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Set Pi-hole password
pihole -a -p admin123

print_status "✅ Pi-hole installed!"
```

### Step 4: Update Firewall Rules

Also update the firewall rules section (around line 320):

```bash
# Change this:
ufw allow 80/tcp    # Nginx (no conflict with AdGuard Home!)
ufw allow 3000/tcp  # AdGuard Home Web UI

# To this:
ufw allow 81/tcp    # Nginx (Pi-hole uses port 80)
ufw allow 80/tcp    # Pi-hole FTL
ufw allow 8080/tcp  # Pi-hole Web UI
```

### Step 5: Update Nginx Configuration

Update the nginx section (around line 415) to use port 81:

```bash
# Change this:
listen 80 default_server;
listen [::]:80 default_server;

# To this:
listen 81 default_server;
listen [::]:81 default_server;
```

And update the Pi-hole proxy configuration:

```bash
# Change this:
location /adguard/ {
    proxy_pass http://localhost:3000/;

# To this:
location /admin/ {
    proxy_pass http://localhost:80/admin/;
```

### Step 6: Run the Modified Script

```bash
sudo ./ubuntu-homelab-simple.sh
```

---

## 📋 Option 2: Migrate from AdGuard Home to Pi-hole

If you already have AdGuard Home installed and want to switch to Pi-hole:

### Step 1: Backup Your Current Setup

```bash
# Backup AdGuard Home configuration
sudo cp -r /opt/AdGuardHome /opt/AdGuardHome.backup
sudo cp -r /mnt/ssd-data/adguardhome /mnt/ssd-data/adguardhome.backup

# Backup current DNS settings
sudo cp /etc/resolv.conf /etc/resolv.conf.backup
```

### Step 2: Stop and Remove AdGuard Home

```bash
# Stop AdGuard Home service
sudo systemctl stop AdGuardHome
sudo systemctl disable AdGuardHome

# Uninstall AdGuard Home
sudo /opt/AdGuardHome/AdGuardHome -s uninstall

# Remove AdGuard Home files
sudo rm -rf /opt/AdGuardHome
```

### Step 3: Install Pi-hole

```bash
# Prepare Pi-hole configuration
sudo mkdir -p /etc/pihole
sudo cat > /etc/pihole/setupVars.conf << 'PIHOLE_SETUP'
WEBPASSWORD=
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=192.168.8.2/24
IPV6_ADDRESS=
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=8.8.8.8
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
BLOCKING_ENABLED=true
PIHOLE_SETUP

# Install Pi-hole
curl -sSL https://install.pi-hole.net | sudo bash /dev/stdin --unattended

# Set Pi-hole password
sudo pihole -a -p admin123
```

### Step 4: Update Nginx Configuration

```bash
# Change nginx to port 81 (Pi-hole uses port 80)
sudo sed -i 's/listen 80 default_server;/listen 81 default_server;/g' /etc/nginx/sites-available/homelab
sudo sed -i 's/listen \[::]:80 default_server;/listen [::]:81 default_server;/g' /etc/nginx/sites-available/homelab

# Update Pi-hole proxy location
sudo sed -i 's|location /adguard/|location /admin/|g' /etc/nginx/sites-available/homelab
sudo sed -i 's|proxy_pass http://localhost:3000/;|proxy_pass http://localhost:80/admin/;|g' /etc/nginx/sites-available/homelab

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Update Firewall Rules

```bash
# Remove AdGuard Home ports
sudo ufw delete allow 3000/tcp

# Add Pi-hole ports
sudo ufw allow 80/tcp   # Pi-hole FTL
sudo ufw allow 81/tcp   # Nginx (changed from 80)
sudo ufw allow 8080/tcp # Pi-hole web UI

# Reload firewall
sudo ufw reload
```

### Step 6: Update Dashboard HTML

```bash
sudo nano /var/www/html/index.html
```

Find the AdGuard Home link and change it to Pi-hole:

```html
<!-- Change this: -->
<a href="http://192.168.8.2:3000" class="service-card">
    <h3>🛡️ AdGuard Home</h3>
    <p>DNS filtering & ad blocking</p>
</a>

<!-- To this: -->
<a href="http://192.168.8.2:8080/admin" class="service-card">
    <h3>🛡️ Pi-hole</h3>
    <p>DNS filtering & ad blocking</p>
</a>
```

### Step 7: Verify Installation

```bash
# Check Pi-hole status
sudo systemctl status pihole-FTL

# Test DNS resolution
nslookup google.com 192.168.8.2

# Check services are running on correct ports
ss -tlnp | grep -E ':(80|81|8080)'

# Access Pi-hole web interface
# http://192.168.8.2:8080/admin
# Password: admin123
```

---

## 🔧 Managing Pi-hole

### Basic Commands

```bash
# Check Pi-hole status
sudo systemctl status pihole-FTL

# Restart Pi-hole
sudo systemctl restart pihole-FTL

# Update blocklists
pihole -g

# Reset password
pihole -a -p newpassword

# View live DNS queries
pihole -t

# Check Pi-hole version
pihole -v

# Repair Pi-hole
pihole -r
```

### Port Conflict Resolution

If nginx won't start after installing Pi-hole:

```bash
# Pi-hole FTL binds to port 80 by default
# Solution 1: Change nginx to port 81 (recommended)
sudo sed -i 's/listen 80 default_server;/listen 81 default_server;/g' /etc/nginx/sites-available/homelab
sudo systemctl restart nginx

# Solution 2: Change Pi-hole FTL port (advanced)
# Edit /etc/lighttpd/lighttpd.conf
# Change: server.port = 80
# To: server.port = 8080
sudo systemctl restart lighttpd
```

### Troubleshooting

```bash
# Fix DNS conflicts with systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
pihole reconfigure
sudo systemctl restart pihole-FTL

# Check Pi-hole logs
sudo journalctl -u pihole-FTL --since "1 hour ago"
cat /var/log/pihole/pihole.log

# Repair Pi-hole installation
pihole -r
# Choose "Repair" option

# Check DNS forwarding
pihole -q google.com

# Test blocked domain
pihole -q ads.google.com
```

---

## 📊 Pi-hole vs AdGuard Home Comparison

| Feature | Pi-hole | AdGuard Home |
|---------|---------|--------------|
| **Web UI Port** | 80 (FTL) + 8080 (admin) | 3000 |
| **Port Conflicts** | Yes (with nginx on port 80) | No |
| **DNS-over-HTTPS** | Plugin required | Built-in |
| **DNS-over-TLS** | Plugin required | Built-in |
| **Web Interface** | Mature, feature-rich | Modern, responsive |
| **Mobile App** | Third-party | Official app available |
| **Community** | Very large | Growing |
| **Per-client Settings** | Basic | Advanced |
| **Parental Controls** | No | Yes |
| **Installation** | Script-based | Binary download |
| **Resource Usage** | ~200MB RAM | ~150MB RAM |
| **Blocklist Management** | Excellent | Good |
| **Query Logging** | Excellent | Good |

---

## 🔄 Migrating Back to AdGuard Home

If you decide to switch back to AdGuard Home:

```bash
# Download and run the migration script
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/ubuntu-homelab-simple.sh
chmod +x ubuntu-homelab-simple.sh

# Or reinstall from scratch
sudo ./ubuntu-homelab-simple.sh
```

---

## 📚 Additional Resources

- **[Pi-hole Documentation](https://docs.pi-hole.net/)**
- **[Pi-hole Discourse Forum](https://discourse.pi-hole.net/)**
- **[Pi-hole GitHub](https://github.com/pi-hole/pi-hole)**
- **[AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)**

---

**💡 Recommendation**: Try both solutions! AdGuard Home is easier to set up (no port conflicts), but Pi-hole has a larger community. Both are excellent choices for DNS filtering and ad-blocking.
