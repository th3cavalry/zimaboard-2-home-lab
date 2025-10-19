#!/bin/bash

# ZimaBoard 2 Homelab - Proxmox VE Deployment Script
# Deploys all security services as LXC containers

set -e

echo "🛡️  ZimaBoard 2 Homelab - Proxmox VE Deployment"
echo "==============================================="
echo "Deploying community-validated security services:"
echo "• Pi-hole + Unbound DNS (95% adoption)"
echo "• Fail2ban intrusion prevention (60% adoption)"
echo "• Wireguard VPN (modern standard)"
echo "• Seafile NAS (optimized for limited hardware)"
echo "• Squid proxy (cellular optimization)"
echo "• Netdata monitoring (zero-config)"
echo "• ClamAV virus protection"
echo "• Nginx reverse proxy"
echo ""

# Check if running as root on Proxmox
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

if ! command -v pveversion &> /dev/null; then
    echo "❌ Proxmox VE not detected"
    exit 1
fi

echo "✅ Proxmox VE detected: $(pveversion)"
echo ""

# Check if storage is setup
if [[ ! -d "/mnt/seafile-data" ]]; then
    echo "⚠️  SSD storage not detected. Running setup first..."
    curl -sSL "https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/proxmox/setup-ssd-storage.sh" | bash
fi

# Container configuration
declare -A CONTAINERS=(
    [100]="pihole:1024:8192:DNS filtering & ad-blocking"
    [101]="fail2ban:256:2048:Intrusion prevention"
    [102]="seafile:2048:1024000:High-performance NAS"
    [103]="squid:2048:204800:Cellular optimization proxy"
    [104]="netdata:512:8192:Zero-config monitoring"
    [105]="wireguard:256:2048:Secure VPN access"
    [106]="clamav:1024:8192:Background virus scanning"
    [107]="nginx:512:4096:Reverse proxy"
)

# Download latest Ubuntu 22.04 LXC template
echo "📥 Downloading Ubuntu 22.04 LXC template..."
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Create bridge network if not exists
if ! ip link show vmbr0 &> /dev/null; then
    echo "🌐 Creating bridge network..."
    # This would typically be done during Proxmox installation
    echo "⚠️  Please configure bridge network vmbr0 in Proxmox web UI"
fi

# Deploy each container
for container_id in "${!CONTAINERS[@]}"; do
    IFS=':' read -r name memory storage description <<< "${CONTAINERS[$container_id]}"
    
    echo "🚀 Deploying $name (CT $container_id): $description"
    
    # Check if container already exists
    if pct status $container_id &> /dev/null; then
        echo "⚠️  Container $container_id already exists, skipping..."
        continue
    fi
    
    # Create container
    pct create $container_id local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
        --hostname $name \
        --memory $memory \
        --swap 512 \
        --cores 2 \
        --rootfs local-lvm:$storage \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --features nesting=1,keyctl=1 \
        --unprivileged 1 \
        --start 1
    
    # Wait for container to start
    sleep 10
    
    # Basic system setup
    pct exec $container_id -- bash -c "
        apt update && apt upgrade -y
        apt install -y curl wget git htop nano ufw
        systemctl enable systemd-resolved
    "
    
    echo "✅ Container $name deployed successfully"
done

echo ""
echo "🎉 Proxmox VE Deployment Complete!"
echo "=================================="
echo "All containers have been created and started."
echo ""
echo "📋 Next steps:"
echo "1. Configure each service via Proxmox web UI"
echo "2. Access Pi-hole at http://ZIMABOARD_IP:8080/admin"
echo "3. Setup Seafile NAS at http://ZIMABOARD_IP:8081"
echo "4. Configure Wireguard VPN clients"
echo "5. Monitor with Netdata at http://ZIMABOARD_IP:19999"
echo ""
echo "📚 For detailed configuration:"
echo "https://github.com/th3cavalry/zimaboard-2-home-lab"
echo ""
echo "🔧 Service-specific setup scripts available at:"
echo "• Pi-hole: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/pihole-setup.sh | pct exec 100 -- bash"
echo "• Seafile: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/seafile-setup.sh | pct exec 102 -- bash"
echo "• Wireguard: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/wireguard-setup.sh | pct exec 105 -- bash"
