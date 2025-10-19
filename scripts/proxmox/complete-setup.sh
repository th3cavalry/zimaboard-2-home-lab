#!/bin/bash

# ZimaBoard 2 Homelab - Complete Setup Script
# Downloads and runs all setup components from GitHub

set -e

GITHUB_RAW_URL="https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main"

echo "🚀 ZimaBoard 2 Homelab - Complete Setup"
echo "========================================="
echo "This script will set up your complete homelab environment:"
echo "- 2TB SSD storage configuration"
echo "- Proxmox VE containers and services"
echo "- DNS filtering, ad-blocking, VPN, monitoring"
echo "- Cellular optimization and caching"
echo ""

# Check if running on Proxmox
if ! command -v pveversion &> /dev/null; then
    echo "❌ Error: This script requires Proxmox VE"
    echo "Please install Proxmox VE first, then run this script"
    exit 1
fi

echo "✅ Proxmox VE detected: $(pveversion)"
echo ""

# Step 1: Setup SSD Storage
echo "📀 Step 1: Setting up 2TB SSD storage..."
curl -sSL "${GITHUB_RAW_URL}/scripts/proxmox/setup-ssd-storage.sh" | bash
echo "✅ SSD storage setup completed"
echo ""

# Step 2: Deploy all services
echo "🛡️  Step 2: Deploying security services..."
curl -sSL "${GITHUB_RAW_URL}/scripts/proxmox/deploy-proxmox.sh" | bash
echo "✅ Service deployment completed"
echo ""

# Step 3: Setup streaming ad-blocking (if available)
echo "📺 Step 3: Setting up streaming ad-blocking..."
if curl -sSL "${GITHUB_RAW_URL}/scripts/streaming-adblock/setup-streaming-adblock.sh" | bash 2>/dev/null; then
    echo "✅ Streaming ad-blocking setup completed"
else
    echo "⚠️  Streaming ad-blocking setup not available or failed (optional)"
fi
echo ""

# Get ZimaBoard IP for service URLs
ZIMABOARD_IP=$(hostname -I | awk '{print $1}')

echo "🎉 Complete Setup Finished!"
echo "=========================="
echo ""
echo "🌐 Access your services at:"
echo "• Proxmox Web UI: https://${ZIMABOARD_IP}:8006"
echo "• Main Dashboard: http://${ZIMABOARD_IP}:80"
echo "• Pi-hole Admin: http://${ZIMABOARD_IP}:8080/admin"
echo "• Seafile NAS: http://${ZIMABOARD_IP}:8081"
echo "• Netdata Monitoring: http://${ZIMABOARD_IP}:19999"
echo "• Squid Proxy: http://${ZIMABOARD_IP}:3128"
echo ""
echo "🔐 Security features enabled:"
echo "• DNS ad-blocking and filtering"
echo "• Intrusion prevention (Fail2ban)"
echo "• VPN access (Wireguard)"
echo "• Real-time monitoring"
echo "• Virus scanning (ClamAV)"
echo "• Cellular bandwidth optimization"
echo "• Streaming service ad-blocking"
echo ""
echo "📚 For detailed documentation and management:"
echo "https://github.com/th3cavalry/zimaboard-2-home-lab"
echo ""
echo "Happy homelabbing! ��🔒🚀"
