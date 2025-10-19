#!/bin/bash

# ZimaBoard 2 Homelab - Health Check Script
# Checks status of all services and containers

echo "🏥 ZimaBoard 2 Homelab Health Check"
echo "==================================="
echo "Checking all services and containers..."
echo ""

# Check Proxmox host health
echo "🖥️  Proxmox Host Status:"
echo "• Version: $(pveversion)"
echo "• Uptime: $(uptime -p)"
echo "• Memory: $(free -h | grep Mem | awk '{printf "%.1f GB used of %.1f GB (%.1f%%)\n", $3/1024/1024, $2/1024/1024, $3/$2*100}')"
echo "• Storage: $(df -h / | tail -1 | awk '{printf "%s used of %s (%s)\n", $3, $2, $5}')"
echo ""

# Check container status
echo "📦 Container Status:"
declare -A SERVICES=(
    [100]="Pi-hole (DNS & Ad-blocking)"
    [101]="Fail2ban (Intrusion Prevention)"
    [102]="Seafile (NAS Storage)"
    [103]="Squid (Cellular Proxy)"
    [104]="Netdata (Monitoring)"
    [105]="Wireguard (VPN)"
    [106]="ClamAV (Virus Scanning)"
    [107]="Nginx (Reverse Proxy)"
)

for container_id in "${!SERVICES[@]}"; do
    service_name="${SERVICES[$container_id]}"
    if pct status $container_id &> /dev/null; then
        status=$(pct status $container_id | awk '{print $2}')
        if [[ "$status" == "running" ]]; then
            echo "✅ CT $container_id: $service_name - $status"
        else
            echo "❌ CT $container_id: $service_name - $status"
        fi
    else
        echo "❓ CT $container_id: $service_name - not found"
    fi
done

echo ""

# Check network connectivity
echo "🌐 Network Status:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

if ping -c 1 192.168.8.1 &> /dev/null; then
    echo "✅ Gateway connectivity: OK"
else
    echo "❌ Gateway connectivity: FAILED"
fi

echo ""

# Check storage
echo "💾 Storage Status:"
echo "• Seafile NAS: $(df -h /mnt/seafile-data 2>/dev/null | tail -1 | awk '{printf "%s used of %s (%s available)\n", $3, $2, $4}' || echo "Not mounted")"
echo "• Backup storage: $(df -h /mnt/backup-storage 2>/dev/null | tail -1 | awk '{printf "%s used of %s (%s available)\n", $3, $2, $4}' || echo "Not mounted")"

echo ""
echo "📊 Resource Usage Summary:"
echo "• CPU Load: $(cat /proc/loadavg | awk '{print $1 " (1min)"}')"
echo "• Temperature: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C\n", $1/1000}' || echo "N/A")"

echo ""
echo "🔍 Quick Service Tests:"
# Test Pi-hole DNS
if nslookup google.com 127.0.0.1 &> /dev/null; then
    echo "✅ Pi-hole DNS: Responding"
else
    echo "❌ Pi-hole DNS: Not responding"
fi

# Test web services
ZIMABOARD_IP=$(hostname -I | awk '{print $1}')
if curl -s "http://$ZIMABOARD_IP:8080" > /dev/null; then
    echo "✅ Pi-hole Web UI: Accessible"
else
    echo "❌ Pi-hole Web UI: Not accessible"
fi

if curl -s "http://$ZIMABOARD_IP:19999" > /dev/null; then
    echo "✅ Netdata Monitoring: Accessible"
else
    echo "❌ Netdata Monitoring: Not accessible"
fi

echo ""
echo "✅ Health check completed!"
echo "For detailed monitoring, visit: http://$ZIMABOARD_IP:19999"
