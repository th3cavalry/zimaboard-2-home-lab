#!/bin/bash

# Proxmox VE Deployment Script for ZimaBoard 2 Security Homelab
# This script automates the creation of VMs and LXC containers for the security services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ZimaBoard 2 Proxmox Deployment Script ===${NC}"

# Check if running on Proxmox
if ! command -v pvesh &> /dev/null; then
    echo -e "${RED}This script must be run on a Proxmox VE host${NC}"
    exit 1
fi

# Configuration variables
NODE_NAME="zimaboard"
STORAGE_LOCATION="local"
NETWORK_BRIDGE="vmbr0"
BASE_IP="192.168.8"
SUBNET_MASK="24"
GATEWAY="${BASE_IP}.1"
DNS_SERVER="1.1.1.1"

# VM/Container IDs
PIHOLE_ID=100
UNBOUND_ID=101
CLAMAV_ID=102
SURICATA_ID=103
NGINX_ID=104
SQUID_ID=105
PROMETHEUS_ID=200
GRAFANA_ID=201
NEXTCLOUD_ID=300

echo -e "${BLUE}Deployment Configuration:${NC}"
echo -e "Node Name: ${NODE_NAME}"
echo -e "Storage: ${STORAGE_LOCATION}"
echo -e "Network Bridge: ${NETWORK_BRIDGE}"
echo -e "IP Range: ${BASE_IP}.100-110"
echo -e "Gateway: ${GATEWAY}"
echo -e ""

read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

# Function to create LXC container
create_lxc_container() {
    local id=$1
    local name=$2
    local memory=$3
    local disk=$4
    local ip=$5
    local template=$6
    
    echo -e "${YELLOW}Creating LXC container: ${name} (ID: ${id})${NC}"
    
    pct create ${id} ${template} \
        --hostname ${name} \
        --memory ${memory} \
        --rootfs ${STORAGE_LOCATION}:${disk} \
        --cores 1 \
        --net0 name=eth0,bridge=${NETWORK_BRIDGE},ip=${ip}/${SUBNET_MASK},gw=${GATEWAY} \
        --nameserver ${DNS_SERVER} \
        --start \
        --unprivileged 1 \
        --features nesting=1
        
    echo -e "${GREEN}Container ${name} created successfully${NC}"
}

# Function to create VM
create_vm() {
    local id=$1
    local name=$2
    local memory=$3
    local disk=$4
    local ip=$5
    local iso=$6
    
    echo -e "${YELLOW}Creating VM: ${name} (ID: ${id})${NC}"
    
    qm create ${id} \
        --name ${name} \
        --memory ${memory} \
        --cores 2 \
        --sockets 1 \
        --net0 virtio,bridge=${NETWORK_BRIDGE} \
        --scsihw virtio-scsi-pci \
        --scsi0 ${STORAGE_LOCATION}:${disk},format=qcow2 \
        --cdrom ${iso} \
        --boot order=scsi0 \
        --agent enabled=1
        
    echo -e "${GREEN}VM ${name} created successfully${NC}"
}

# Download LXC templates
echo -e "${YELLOW}Downloading LXC templates...${NC}"
pveam update
pveam download local debian-12-standard_12.2-1_amd64.tar.zst || true
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst || true

# Download VM ISOs
echo -e "${YELLOW}Downloading VM ISOs...${NC}"
cd /var/lib/vz/template/iso/
wget -nc https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso || true

# Create security service containers
echo -e "\n${BLUE}=== Creating Security Service Containers ===${NC}"

# Pi-hole LXC Container
create_lxc_container ${PIHOLE_ID} "pihole" 1024 8 "${BASE_IP}.100" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Unbound LXC Container  
create_lxc_container ${UNBOUND_ID} "unbound" 512 4 "${BASE_IP}.101" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# ClamAV LXC Container
create_lxc_container ${CLAMAV_ID} "clamav" 2048 12 "${BASE_IP}.102" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Suricata LXC Container
create_lxc_container ${SURICATA_ID} "suricata" 2048 8 "${BASE_IP}.103" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Nginx LXC Container
create_lxc_container ${NGINX_ID} "nginx" 512 4 "${BASE_IP}.104" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

# Squid Proxy LXC Container
create_lxc_container ${SQUID_ID} "squid" 2048 50 "${BASE_IP}.105" \
    "${STORAGE_LOCATION}:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

echo -e "\n${BLUE}=== Creating Monitoring & NAS VMs ===${NC}"

# Prometheus VM
create_vm ${PROMETHEUS_ID} "prometheus" 1024 16 "${BASE_IP}.106" \
    "${STORAGE_LOCATION}:iso/debian-12.2.0-amd64-netinst.iso"

# Grafana VM  
create_vm ${GRAFANA_ID} "grafana" 2048 20 "${BASE_IP}.107" \
    "${STORAGE_LOCATION}:iso/debian-12.2.0-amd64-netinst.iso"

# Nextcloud NAS VM with larger disk
echo -e "${YELLOW}Creating Nextcloud NAS VM with 1TB storage...${NC}"
qm create ${NEXTCLOUD_ID} \
    --name "nextcloud" \
    --memory 4096 \
    --cores 2 \
    --sockets 1 \
    --net0 virtio,bridge=${NETWORK_BRIDGE} \
    --scsihw virtio-scsi-pci \
    --scsi0 ${STORAGE_LOCATION}:20,format=qcow2 \
    --scsi1 ${STORAGE_LOCATION}:1000,format=qcow2 \
    --cdrom ${STORAGE_LOCATION}:iso/debian-12.2.0-amd64-netinst.iso \
    --boot order=scsi0 \
    --agent enabled=1

echo -e "${GREEN}Nextcloud VM created with 1TB data disk${NC}"

# Configure Pi-hole container
echo -e "\n${BLUE}=== Configuring Pi-hole Container ===${NC}"
sleep 10  # Wait for container to fully start

pct exec ${PIHOLE_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y curl git
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    pihole -a -p admin123
    systemctl enable pihole-FTL
"

# Configure Unbound container
echo -e "\n${BLUE}=== Configuring Unbound Container ===${NC}"
pct exec ${UNBOUND_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y unbound unbound-anchor
    systemctl enable unbound
    systemctl start unbound
"

# Configure ClamAV container
echo -e "\n${BLUE}=== Configuring ClamAV Container ===${NC}"
pct exec ${CLAMAV_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y clamav clamav-daemon clamav-freshclam
    systemctl enable clamav-daemon
    systemctl enable clamav-freshclam
    freshclam
    systemctl start clamav-daemon
"

# Configure Suricata container
echo -e "\n${BLUE}=== Configuring Suricata Container ===${NC}"
pct exec ${SURICATA_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y suricata
    systemctl enable suricata
"

# Configure Nginx container
echo -e "\n${BLUE}=== Configuring Nginx Container ===${NC}"
pct exec ${NGINX_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
"

# Configure Squid container
echo -e "\n${BLUE}=== Configuring Squid Proxy Container ===${NC}"
pct exec ${SQUID_ID} -- bash -c "
    apt update && apt upgrade -y
    apt install -y squid squidclient apache2-utils curl wget bc
    systemctl stop squid
    mkdir -p /var/spool/squid /var/log/squid
    chown -R proxy:proxy /var/spool/squid /var/log/squid
    systemctl enable squid
"

# Create storage directories
echo -e "\n${BLUE}=== Setting up Storage ===${NC}"
mkdir -p /var/lib/vz/snippets
mkdir -p /mnt/nas-storage
mkdir -p /mnt/backups

# Create backup script
echo -e "${YELLOW}Creating backup script...${NC}"
cat > /usr/local/bin/proxmox-backup-all << 'EOSCRIPT'
#!/bin/bash

# Backup all VMs and containers
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/mnt/backups"

echo "Starting backup process: $DATE"

# Backup containers
for CT_ID in 100 101 102 103 104 105; do
    echo "Backing up container $CT_ID..."
    vzdump $CT_ID --mode snapshot --compress gzip --storage local
done

# Backup VMs
for VM_ID in 200 201 300; do
    echo "Backing up VM $VM_ID..."
    vzdump $VM_ID --mode snapshot --compress gzip --storage local
done

echo "Backup process completed: $DATE"

# Clean old backups (keep 7 days)
find /var/lib/vz/dump/ -name "*.tar.gz" -mtime +7 -delete
find /var/lib/vz/dump/ -name "*.vma.gz" -mtime +7 -delete
EOSCRIPT

chmod +x /usr/local/bin/proxmox-backup-all

# Add weekly backup cron job
echo "0 2 * * 0 /usr/local/bin/proxmox-backup-all" >> /etc/crontab

# Create health check script
echo -e "${YELLOW}Creating health check script...${NC}"
cat > /usr/local/bin/proxmox-health-check << 'EOSCRIPT'
#!/bin/bash

echo "=== Proxmox Health Check ==="
echo "Date: $(date)"
echo ""

echo "=== Node Status ==="
pvesh get /nodes/zimaboard/status

echo ""
echo "=== Container Status ==="
pct list

echo ""
echo "=== VM Status ==="
qm list

echo ""
echo "=== Storage Usage ==="
df -h

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Network Status ==="
ip addr show

echo ""
echo "=== Service Status ==="
echo "Pi-hole: $(pct exec 100 -- systemctl is-active pihole-FTL 2>/dev/null || echo 'unknown')"
echo "Unbound: $(pct exec 101 -- systemctl is-active unbound 2>/dev/null || echo 'unknown')"
echo "ClamAV: $(pct exec 102 -- systemctl is-active clamav-daemon 2>/dev/null || echo 'unknown')"
echo "Suricata: $(pct exec 103 -- systemctl is-active suricata 2>/dev/null || echo 'unknown')"
echo "Nginx: $(pct exec 104 -- systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo "Squid: $(pct exec 105 -- systemctl is-active squid 2>/dev/null || echo 'unknown')"
EOSCRIPT

chmod +x /usr/local/bin/proxmox-health-check

# Display deployment summary
echo -e "\n${GREEN}=== Deployment Summary ===${NC}"
echo -e "${BLUE}LXC Containers:${NC}"
echo -e "  Pi-hole (${PIHOLE_ID}): ${BASE_IP}.100 - DNS Filtering & Ad-blocking"
echo -e "  Unbound (${UNBOUND_ID}): ${BASE_IP}.101 - Recursive DNS Resolver"
echo -e "  ClamAV (${CLAMAV_ID}): ${BASE_IP}.102 - Antivirus Scanning"
echo -e "  Suricata (${SURICATA_ID}): ${BASE_IP}.103 - Intrusion Detection"
echo -e "  Nginx (${NGINX_ID}): ${BASE_IP}.104 - Reverse Proxy"
echo -e "  Squid (${SQUID_ID}): ${BASE_IP}.105 - Web/Gaming/Streaming Cache"
echo -e ""
echo -e "${BLUE}Virtual Machines:${NC}"
echo -e "  Prometheus (${PROMETHEUS_ID}): ${BASE_IP}.106 - Metrics Collection"
echo -e "  Grafana (${GRAFANA_ID}): ${BASE_IP}.107 - Monitoring Dashboards"
echo -e "  Nextcloud (${NEXTCLOUD_ID}): ${BASE_IP}.108 - NAS & File Storage (1TB)"
echo -e ""
echo -e "${BLUE}Access URLs:${NC}"
echo -e "  Proxmox Web UI: https://${BASE_IP}.100:8006"
echo -e "  Pi-hole Admin: http://${BASE_IP}.100:8080/admin"
echo -e "  Grafana: http://${BASE_IP}.107:3000"
echo -e "  Nextcloud: http://${BASE_IP}.108:8081"
echo -e "  Squid Proxy: http://${BASE_IP}.105:3128"
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Complete VM installations via Proxmox Web UI"
echo -e "2. Configure network settings in GL.iNet X3000"
echo -e "3. Set ${BASE_IP}.100 as primary DNS server"
echo -e "4. Configure proxy settings to use ${BASE_IP}.105:3128"
echo -e "5. Install Nextcloud using the provided script"
echo -e "6. Install Squid configuration using the provided script"
echo -e "7. Change all default passwords"
echo -e "8. Configure SSL certificates"
echo -e ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${YELLOW}Run 'proxmox-health-check' to verify all services${NC}"
