#!/bin/bash

# ZimaBoard 2 Homelab Deployment Verification Script
# Tests all services and provides comprehensive status report

echo "🔍 ZimaBoard 2 Homelab - Deployment Verification"
echo "=============================================="
echo ""

# System Information
echo "📊 SYSTEM STATUS:"
echo "• Proxmox VE: $(pveversion | head -n1)"
echo "• Kernel: $(uname -r)" 
echo "• Uptime: $(uptime -p)"
echo "• Memory: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
echo ""

# Storage Status
echo "💾 STORAGE CONFIGURATION:"
pvesm status
echo ""

echo "�� DISK USAGE:"
df -h | grep -E "(mmcblk|sda|nvme)" | while read line; do
    echo "  $line"
done
echo ""

# Container Status
echo "🔧 CONTAINER STATUS:"
pct list
echo ""

# Service Testing
echo "🌐 SERVICE CONNECTIVITY TESTS:"

# Test Pi-hole
if curl -s -I http://localhost:8080/admin >/dev/null 2>&1; then
    echo "✅ Pi-hole Admin: http://$(hostname -I | awk '{print $1}'):8080/admin"
else
    echo "❌ Pi-hole Admin: Not accessible"
fi

# Test Seafile  
if pct exec 101 -- systemctl is-active seafile >/dev/null 2>&1; then
    echo "✅ Seafile Server: http://$(hostname -I | awk '{print $1}'):8000"
else
    echo "❌ Seafile Server: Not running"
fi

# Test Wireguard
if pct exec 102 -- wg show wg0 >/dev/null 2>&1; then
    echo "✅ Wireguard VPN: Active (config in container 102)"
else
    echo "❌ Wireguard VPN: Not active"
fi

# Test Squid
if pct exec 103 -- systemctl is-active squid >/dev/null 2>&1; then
    echo "✅ Squid Proxy: $(hostname -I | awk '{print $1}'):3128"
else
    echo "❌ Squid Proxy: Not running"
fi

# Test Nginx
if pct exec 105 -- systemctl is-active nginx >/dev/null 2>&1; then
    echo "✅ Nginx Web Server: http://$(hostname -I | awk '{print $1}')"
else
    echo "❌ Nginx Web Server: Not running"
fi

echo ""

# eMMC Health Check
echo "📱 eMMC OPTIMIZATION STATUS:"
if mount | grep -q "noatime"; then
    echo "✅ noatime mount options applied"
else
    echo "⚠️  noatime mount options not detected"
fi

if [ -f "/var/log/emmc-health.log" ]; then
    echo "✅ eMMC health monitoring active"
else
    echo "⚠️  eMMC health monitoring not found"
fi

if [ "$(cat /proc/sys/vm/swappiness)" -le "10" ]; then
    echo "✅ Optimized swappiness: $(cat /proc/sys/vm/swappiness)"
else
    echo "⚠️  Swappiness not optimized: $(cat /proc/sys/vm/swappiness)"
fi

echo ""

# Quick Performance Test
echo "⚡ QUICK PERFORMANCE TEST:"
echo "• SSD Write Test (100MB):"
if [ -d "/mnt/seafile-data" ]; then
    cd /mnt/seafile-data
    time dd if=/dev/zero of=test.tmp bs=1M count=100 conv=sync 2>&1 | tail -3
    rm -f test.tmp
    echo "✅ SSD performance test completed"
else
    echo "❌ SSD mount point not found"
fi

echo ""

# Summary
echo "🎉 DEPLOYMENT SUMMARY:"
echo "======================================"
TOTAL_CONTAINERS=$(pct list | wc -l)
RUNNING_CONTAINERS=$(pct list | grep running | wc -l)
echo "• Total Containers: $((TOTAL_CONTAINERS-1))"
echo "• Running Containers: $RUNNING_CONTAINERS"

STORAGE_POOLS=$(pvesm status | wc -l)
echo "• Storage Pools: $((STORAGE_POOLS-1))"

echo "• ZimaBoard IP: $(hostname -I | awk '{print $1}')"
echo "• Proxmox Web UI: https://$(hostname -I | awk '{print $1}'):8006"

echo ""
echo "✅ Deployment verification complete!"
echo "📖 Full documentation: https://github.com/th3cavalry/zimaboard-2-home-lab"

