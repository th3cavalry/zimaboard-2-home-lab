# Proxmox VE Setup for ZimaBoard 2 Security Homelab

## Overview

This guide explains how to set up your ZimaBoard 2 homelab using Proxmox VE as the hypervisor platform, providing better resource management, isolation, and scalability compared to a single-host Docker setup.

## Why Proxmox for ZimaBoard 2?

### Advantages
- **Better Resource Management**: Allocate specific CPU/RAM to each service
- **Service Isolation**: Each service runs in its own VM/LXC container
- **Snapshot & Backup**: Built-in backup and snapshot capabilities
- **Web Management**: Comprehensive web-based management interface
- **High Availability**: Easy to migrate VMs and add clustering later
- **Mixed Workloads**: Run both VMs and lightweight LXC containers
- **Storage Management**: Advanced storage features (ZFS, RAID, etc.)

### ZimaBoard 2 Specifications
- **CPU**: Intel Celeron N3450/J3455 (4 cores)
- **RAM**: 16GB (sufficient for multiple VMs)
- **Storage**: 32GB eMMC + SATA expansion
- **Network**: 2x Gigabit Ethernet ports

## Proxmox Installation

### 1. Prepare Installation Media

```bash
# Download Proxmox VE ISO
wget https://www.proxmox.com/en/downloads/category/iso-images-pve

# Create bootable USB (on another machine)
dd if=proxmox-ve_8.1-2.iso of=/dev/sdX bs=1M status=progress
```

### 2. Install Proxmox VE

1. **Boot from USB** on ZimaBoard 2
2. **Installation Options**:
   - Target Disk: eMMC (32GB) for Proxmox OS
   - Filesystem: ext4 (for eMMC) or ZFS (if using SATA SSD)
   - Country/Timezone: Your location
   - Password: Strong root password
   - Email: Your email for notifications
   - Network: Configure static IP (e.g., 192.168.8.100/24)
   - Gateway: 192.168.8.1 (GL.iNet X3000)
   - DNS: 1.1.1.1

3. **Post-Installation Setup**:
   ```bash
   # Update system
   apt update && apt upgrade -y
   
   # Remove enterprise repository (if using free version)
   rm /etc/apt/sources.list.d/pve-enterprise.list
   
   # Add no-subscription repository
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
   
   # Update package lists
   apt update
   ```

## Network Configuration

### 1. Proxmox Network Setup

```bash
# Edit network configuration
nano /etc/network/interfaces
```

```bash
# Proxmox Network Configuration
auto lo
iface lo inet loopback

# Physical interface (connected to GL.iNet X3000)
auto enp1s0
iface enp1s0 inet manual

# Bridge for VMs (connected to physical interface)
auto vmbr0
iface vmbr0 inet static
    address 192.168.8.100/24
    gateway 192.168.8.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0

# Internal bridge for homelab services
auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s '10.0.0.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '10.0.0.0/24' -o vmbr0 -j MASQUERADE
```

### 2. Restart Networking

```bash
systemctl restart networking
```

## VM/Container Layout

### Resource Allocation Plan

| Service | Type | CPU | RAM | Disk | IP |
|---------|------|-----|-----|------|-----|
| **Pi-hole + Unbound** | LXC | 1 core | 1GB | 8GB | 10.0.0.10 |
| **Suricata IDS** | LXC | 2 cores | 2GB | 16GB | 10.0.0.20 |
| **ClamAV** | LXC | 1 core | 2GB | 16GB | 10.0.0.30 |
| **Monitoring Stack** | VM | 2 cores | 4GB | 32GB | 10.0.0.40 |
| **Nginx Proxy** | LXC | 1 core | 512MB | 4GB | 10.0.0.50 |
| **Management** | LXC | 1 core | 1GB | 8GB | 10.0.0.60 |

### Storage Setup

```bash
# Add SATA SSD for VM storage (if available)
# Assuming you've added a SATA SSD to ZimaBoard 2

# Create storage for VMs
pvesm add dir vm-storage --path /mnt/ssd --content images,vztmpl,snippets
```

## LXC Container Creation Scripts

### 1. Pi-hole + Unbound DNS Container

```bash
# Create LXC container for DNS services
pct create 110 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
  --hostname pihole-dns \
  --cores 1 \
  --memory 1024 \
  --swap 512 \
  --net0 name=eth0,bridge=vmbr1,ip=10.0.0.10/24,gw=10.0.0.1 \
  --storage vm-storage \
  --rootfs vm-storage:8 \
  --unprivileged 1 \
  --start 1

# Configure Pi-hole container
pct exec 110 -- bash -c "
apt update && apt upgrade -y
apt install -y curl wget dnsutils

# Install Pi-hole
curl -sSL https://install.pi-hole.net | bash

# Install Unbound
apt install -y unbound
"

# Copy Unbound configuration
pct push 110 /path/to/unbound.conf /etc/unbound/unbound.conf

# Restart services
pct exec 110 -- systemctl restart unbound pihole-FTL
```

### 2. Suricata IDS Container

```bash
# Create LXC container for Suricata
pct create 120 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
  --hostname suricata-ids \
  --cores 2 \
  --memory 2048 \
  --swap 1024 \
  --net0 name=eth0,bridge=vmbr1,ip=10.0.0.20/24,gw=10.0.0.1 \
  --storage vm-storage \
  --rootfs vm-storage:16 \
  --unprivileged 0 \
  --features nesting=1 \
  --start 1

# Install Suricata
pct exec 120 -- bash -c "
apt update && apt upgrade -y
apt install -y software-properties-common
add-apt-repository ppa:oisf/suricata-stable
apt update
apt install -y suricata suricata-update

# Configure Suricata for network monitoring
suricata-update
systemctl enable suricata
systemctl start suricata
"
```

### 3. ClamAV Antivirus Container

```bash
# Create LXC container for ClamAV
pct create 130 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
  --hostname clamav-scanner \
  --cores 1 \
  --memory 2048 \
  --swap 1024 \
  --net0 name=eth0,bridge=vmbr1,ip=10.0.0.30/24,gw=10.0.0.1 \
  --storage vm-storage \
  --rootfs vm-storage:16 \
  --unprivileged 1 \
  --start 1

# Install ClamAV
pct exec 130 -- bash -c "
apt update && apt upgrade -y
apt install -y clamav clamav-daemon clamav-freshclam

# Configure ClamAV
systemctl stop clamav-freshclam
freshclam
systemctl start clamav-freshclam
systemctl enable clamav-freshclam clamav-daemon
systemctl start clamav-daemon
"
```

## VM Creation for Monitoring Stack

### Monitoring VM (Prometheus + Grafana)

```bash
# Create VM for monitoring stack
qm create 140 \
  --name monitoring-stack \
  --memory 4096 \
  --cores 2 \
  --net0 virtio,bridge=vmbr1 \
  --scsi0 vm-storage:32 \
  --ostype l26 \
  --boot c \
  --bootdisk scsi0

# Download Ubuntu Server ISO
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso -O /var/lib/vz/template/iso/ubuntu-22.04-server.iso

# Attach ISO to VM
qm set 140 --ide2 local:iso/ubuntu-22.04-server.iso,media=cdrom

# Start VM for installation
qm start 140
```

### Monitoring Stack Installation

```bash
# After Ubuntu installation, install Docker
ssh user@10.0.0.40

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Create monitoring stack
mkdir -p ~/monitoring
cd ~/monitoring

# Create docker-compose.yml for monitoring
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana_data:/var/lib/grafana

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'

volumes:
  prometheus_data:
  grafana_data:
COMPOSE_EOF

# Start monitoring stack
docker-compose up -d
```

## Automated Deployment Script

```bash
#!/bin/bash
# Proxmox ZimaBoard 2 Homelab Deployment Script

cat > /home/th3cavalry/zimaboard-2-home-lab/scripts/proxmox-deploy.sh << 'SCRIPT_EOF'
#!/bin/bash

# Proxmox ZimaBoard 2 Homelab Automated Deployment
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running on Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    log "Proxmox VE detected"
}

# Download container templates
download_templates() {
    log "Downloading LXC templates..."
    
    # Download Ubuntu 22.04 template
    pveam update
    pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.xz
}

# Create Pi-hole DNS container
create_pihole_container() {
    log "Creating Pi-hole + Unbound DNS container..."
    
    pct create 110 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
      --hostname pihole-dns \
      --cores 1 \
      --memory 1024 \
      --swap 512 \
      --net0 name=eth0,bridge=vmbr1,ip=10.0.0.10/24,gw=10.0.0.1 \
      --storage local \
      --rootfs local:8 \
      --unprivileged 1 \
      --onboot 1 \
      --start 1
    
    # Wait for container to start
    sleep 10
    
    # Install Pi-hole and Unbound
    pct exec 110 -- bash -c "
        apt update && apt upgrade -y
        apt install -y curl wget dnsutils unbound
        
        # Install Pi-hole
        curl -sSL https://install.pi-hole.net | PIHOLE_SKIP_OS_CHECK=true bash /dev/stdin --unattended
        
        # Configure Unbound
        cat > /etc/unbound/unbound.conf.d/pi-hole.conf << 'UNBOUND_EOF'
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    use-caps-for-id: no
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    num-threads: 1
    msg-cache-slabs: 8
    rrset-cache-slabs: 8
    infra-cache-slabs: 8
    key-cache-slabs: 8
    rrset-cache-size: 256m
    msg-cache-size: 128m
    so-rcvbuf: 1m
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
UNBOUND_EOF
        
        systemctl restart unbound
        systemctl enable unbound
        
        # Configure Pi-hole to use Unbound
        echo 'PIHOLE_DNS_1=127.0.0.1#5335' >> /etc/pihole/setupVars.conf
        pihole restartdns
    "
    
    log "Pi-hole + Unbound container created successfully"
}

# Create Suricata IDS container
create_suricata_container() {
    log "Creating Suricata IDS container..."
    
    pct create 120 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
      --hostname suricata-ids \
      --cores 2 \
      --memory 2048 \
      --swap 1024 \
      --net0 name=eth0,bridge=vmbr1,ip=10.0.0.20/24,gw=10.0.0.1 \
      --storage local \
      --rootfs local:16 \
      --unprivileged 0 \
      --features nesting=1 \
      --onboot 1 \
      --start 1
    
    sleep 10
    
    pct exec 120 -- bash -c "
        apt update && apt upgrade -y
        apt install -y software-properties-common
        add-apt-repository ppa:oisf/suricata-stable -y
        apt update
        apt install -y suricata suricata-update
        
        # Update rules
        suricata-update
        
        # Configure Suricata
        systemctl enable suricata
        systemctl start suricata
    "
    
    log "Suricata IDS container created successfully"
}

# Create ClamAV container
create_clamav_container() {
    log "Creating ClamAV antivirus container..."
    
    pct create 130 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
      --hostname clamav-scanner \
      --cores 1 \
      --memory 2048 \
      --swap 1024 \
      --net0 name=eth0,bridge=vmbr1,ip=10.0.0.30/24,gw=10.0.0.1 \
      --storage local \
      --rootfs local:16 \
      --unprivileged 1 \
      --onboot 1 \
      --start 1
    
    sleep 10
    
    pct exec 130 -- bash -c "
        apt update && apt upgrade -y
        apt install -y clamav clamav-daemon clamav-freshclam
        
        # Update virus definitions
        systemctl stop clamav-freshclam
        freshclam
        
        # Enable services
        systemctl enable clamav-freshclam clamav-daemon
        systemctl start clamav-freshclam clamav-daemon
    "
    
    log "ClamAV container created successfully"
}

# Create Nginx proxy container
create_nginx_container() {
    log "Creating Nginx reverse proxy container..."
    
    pct create 150 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.xz \
      --hostname nginx-proxy \
      --cores 1 \
      --memory 512 \
      --swap 256 \
      --net0 name=eth0,bridge=vmbr0,ip=192.168.8.200/24,gw=192.168.8.1 \
      --net1 name=eth1,bridge=vmbr1,ip=10.0.0.50/24 \
      --storage local \
      --rootfs local:4 \
      --unprivileged 1 \
      --onboot 1 \
      --start 1
    
    sleep 10
    
    pct exec 150 -- bash -c "
        apt update && apt upgrade -y
        apt install -y nginx
        
        # Configure Nginx as reverse proxy
        cat > /etc/nginx/sites-available/homelab << 'NGINX_EOF'
server {
    listen 80 default_server;
    server_name _;
    
    location /pihole/ {
        proxy_pass http://10.0.0.10/admin/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /grafana/ {
        proxy_pass http://10.0.0.40:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /prometheus/ {
        proxy_pass http://10.0.0.40:9090/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location / {
        return 200 'ZimaBoard 2 Security Homelab - Proxmox Edition';
        add_header Content-Type text/plain;
    }
}
NGINX_EOF
        
        ln -s /etc/nginx/sites-available/homelab /etc/nginx/sites-enabled/
        rm /etc/nginx/sites-enabled/default
        
        systemctl restart nginx
        systemctl enable nginx
    "
    
    log "Nginx reverse proxy container created successfully"
}

# Configure routing and firewall
configure_networking() {
    log "Configuring networking and firewall..."
    
    # Enable IP forwarding on Proxmox host
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    
    # Configure iptables rules
    iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o vmbr0 -j MASQUERADE
    iptables -A FORWARD -i vmbr1 -o vmbr0 -j ACCEPT
    iptables -A FORWARD -i vmbr0 -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Make iptables rules persistent
    apt install -y iptables-persistent
    iptables-save > /etc/iptables/rules.v4
    
    log "Networking configured successfully"
}

# Main deployment function
main() {
    log "Starting ZimaBoard 2 Proxmox Homelab Deployment..."
    
    check_proxmox
    download_templates
    create_pihole_container
    create_suricata_container
    create_clamav_container
    create_nginx_container
    configure_networking
    
    log "Deployment completed successfully!"
    
    echo ""
    echo "🏠 ZimaBoard 2 Proxmox Homelab - Access Information"
    echo "=================================================="
    echo ""
    echo "📊 Proxmox Web UI:     https://192.168.8.100:8006"
    echo "🛡️  Pi-hole Admin:      http://192.168.8.200/pihole/"
    echo "📈 Grafana:            http://192.168.8.200/grafana/"
    echo "📊 Prometheus:         http://192.168.8.200/prometheus/"
    echo ""
    echo "🔐 Default Credentials:"
    echo "   Proxmox:     root / [set during installation]"
    echo "   Pi-hole:     admin / [randomly generated]"
    echo "   Grafana:     admin / admin123"
    echo ""
    echo "📋 Container Status:"
    pct list
    echo ""
    echo "⚡ Services are automatically started on boot"
}

# Run deployment
main "$@"
SCRIPT_EOF

chmod +x /home/th3cavalry/zimaboard-2-home-lab/scripts/proxmox-deploy.sh
```

## Proxmox Management

### Backup Configuration

```bash
# Create backup schedule
cat > /etc/cron.d/homelab-backup << 'EOF'
# Backup all containers daily at 2 AM
0 2 * * * root vzdump --mode snapshot --compress lzo --storage local --all 1

# Clean old backups (keep 7 days)
0 3 * * * root find /var/lib/vz/dump -name "*.tar.lzo" -mtime +7 -delete
