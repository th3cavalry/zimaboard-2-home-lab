#!/bin/bash

# Squid Proxy Installation Script for ZimaBoard 2
# Optimized for cellular network caching

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Squid Proxy Installation Script ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install Squid and dependencies
echo -e "${YELLOW}Installing Squid proxy...${NC}"
apt install -y squid squidclient apache2-utils curl wget logrotate htop iotop

# Stop Squid service
echo -e "${YELLOW}Stopping Squid service...${NC}"
systemctl stop squid

# Backup original configuration
echo -e "${YELLOW}Backing up original configuration...${NC}"
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup.$(date +%Y%m%d_%H%M%S)

# Copy optimized configuration
echo -e "${YELLOW}Installing optimized configuration...${NC}"
cp /tmp/squid.conf /etc/squid/squid.conf

# Create cache directory structure
echo -e "${YELLOW}Setting up cache directories...${NC}"
mkdir -p /var/spool/squid
mkdir -p /var/log/squid
mkdir -p /etc/squid/conf.d

# Set permissions
chown -R proxy:proxy /var/spool/squid
chown -R proxy:proxy /var/log/squid
chmod 750 /var/spool/squid
chmod 750 /var/log/squid

# Initialize cache directories
echo -e "${YELLOW}Initializing cache directories...${NC}"
squid -z

# Create cache statistics script
echo -e "${YELLOW}Creating cache statistics script...${NC}"
cat > /usr/local/bin/squid-stats << 'EOSTATS'
#!/bin/bash

echo "=== Squid Cache Statistics ==="
echo "Date: $(date)"
echo ""

echo "=== Cache Summary ==="
squidclient -h localhost cache_object://localhost/info 2>/dev/null | grep -E "(Number of|Storage|Memory)" || echo "Stats not available"

echo ""
echo "=== Cache Directory Usage ==="
du -sh /var/spool/squid/* 2>/dev/null | head -10 || echo "No cache data"

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Active Connections ==="
netstat -an | grep :3128 | wc -l

echo ""
echo "=== Recent Cache Hits (last 100 entries) ==="
tail -100 /var/log/squid/access.log | grep "TCP_HIT\|TCP_MEM_HIT" | wc -l

echo ""
echo "=== Cache Hit Ratio (last 1000 requests) ==="
TOTAL=$(tail -1000 /var/log/squid/access.log | wc -l)
HITS=$(tail -1000 /var/log/squid/access.log | grep -c "TCP_HIT\|TCP_MEM_HIT" || echo 0)
if [ $TOTAL -gt 0 ]; then
    RATIO=$(echo "scale=2; $HITS * 100 / $TOTAL" | bc 2>/dev/null || echo "N/A")
    echo "Hit Ratio: $HITS/$TOTAL ($RATIO%)"
else
    echo "No recent requests"
fi

echo ""
echo "=== Top Cached Domains ==="
tail -1000 /var/log/squid/access.log | grep "TCP_HIT\|TCP_MEM_HIT" | awk '{print $7}' | sed 's|.*://||' | sed 's|/.*||' | sort | uniq -c | sort -nr | head -10 || echo "No cache hits"

echo ""
echo "=== Bandwidth Saved (estimated) ==="
CACHE_HITS_SIZE=$(tail -1000 /var/log/squid/access.log | grep "TCP_HIT\|TCP_MEM_HIT" | awk '{sum += $5} END {print sum/1024/1024}' 2>/dev/null || echo 0)
echo "Approximate data saved from cache: ${CACHE_HITS_SIZE} MB (last 1000 requests)"

echo ""
echo "=== Cache Storage Breakdown ==="
echo "Total cache size: $(du -sh /var/spool/squid 2>/dev/null | cut -f1 || echo 'N/A')"
echo "Cache utilization: $(df -h /var/spool/squid | tail -1 | awk '{print $5}' || echo 'N/A')"
EOSTATS

chmod +x /usr/local/bin/squid-stats

# Create cache cleanup script
echo -e "${YELLOW}Creating cache cleanup script...${NC}"
cat > /usr/local/bin/squid-cleanup << 'EOCLEANUP'
#!/bin/bash

echo "=== Squid Cache Cleanup ==="
echo "Date: $(date)"

# Stop Squid
systemctl stop squid

# Clean cache directories
echo "Cleaning cache directories..."
rm -rf /var/spool/squid/*

# Reinitialize cache
echo "Reinitializing cache..."
squid -z

# Start Squid
systemctl start squid

echo "Cache cleanup completed!"
EOCLEANUP

chmod +x /usr/local/bin/squid-cleanup

# Create bandwidth monitoring script
echo -e "${YELLOW}Creating bandwidth monitoring script...${NC}"
cat > /usr/local/bin/squid-bandwidth << 'EOBANDWIDTH'
#!/bin/bash

LOGFILE="/var/log/squid/access.log"
TIMEFRAME=${1:-60}  # Default to last 60 minutes

echo "=== Squid Bandwidth Analysis (Last $TIMEFRAME minutes) ==="
echo "Date: $(date)"
echo ""

# Calculate time threshold
THRESHOLD=$(date -d "$TIMEFRAME minutes ago" +"%s")

# Parse logs and calculate bandwidth
awk -v threshold="$THRESHOLD" '
BEGIN {
    total_requests = 0
    cache_hits = 0
    cache_misses = 0
    bytes_sent = 0
    bytes_saved = 0
}
{
    # Parse timestamp (assuming squid log format)
    if ($1 >= threshold) {
        total_requests++
        bytes = $5
        status = $4
        
        if (status ~ /TCP_HIT|TCP_MEM_HIT/) {
            cache_hits++
            bytes_saved += bytes
        } else {
            cache_misses++
        }
        bytes_sent += bytes
    }
}
END {
    if (total_requests > 0) {
        hit_ratio = (cache_hits / total_requests) * 100
        print "Total Requests: " total_requests
        print "Cache Hits: " cache_hits
        print "Cache Misses: " cache_misses
        print "Hit Ratio: " sprintf("%.2f%%", hit_ratio)
        print "Total Bytes Sent: " sprintf("%.2f MB", bytes_sent/1024/1024)
        print "Bytes Saved from Cache: " sprintf("%.2f MB", bytes_saved/1024/1024)
        print "Bandwidth Savings: " sprintf("%.2f%%", (bytes_saved/bytes_sent)*100)
    } else {
        print "No requests in the specified timeframe"
    }
}' "$LOGFILE"
EOBANDWIDTH

chmod +x /usr/local/bin/squid-bandwidth

# Configure log rotation
echo -e "${YELLOW}Configuring log rotation...${NC}"
cat > /etc/logrotate.d/squid << 'EOLOGROTATE'
/var/log/squid/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 proxy proxy
    postrotate
        systemctl reload squid
    endscript
}
EOLOGROTATE

# Create systemd service for cache warming
echo -e "${YELLOW}Creating cache warming service...${NC}"
cat > /etc/systemd/system/squid-cache-warm.service << 'EOSERVICE'
[Unit]
Description=Squid Cache Warming Service
After=squid.service
Requires=squid.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/squid-cache-warm
User=proxy
Group=proxy

[Install]
WantedBy=multi-user.target
EOSERVICE

cat > /usr/local/bin/squid-cache-warm << 'EOWARM'
#!/bin/bash

# Warm cache with commonly accessed content
URLS=(
    "http://archive.ubuntu.com/ubuntu/dists/jammy/Release"
    "http://security.ubuntu.com/ubuntu/dists/jammy-security/Release"
    "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
    "https://www.google.com"
    "https://www.youtube.com"
    "https://cdn.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"
)

echo "Warming Squid cache..."
for url in "${URLS[@]}"; do
    echo "Fetching: $url"
    curl -s -x localhost:3128 "$url" > /dev/null 2>&1 || true
done
echo "Cache warming completed!"
EOWARM

chmod +x /usr/local/bin/squid-cache-warm

# Configure firewall (if ufw is available)
if command -v ufw &> /dev/null; then
    echo -e "${YELLOW}Configuring firewall...${NC}"
    ufw allow 3128/tcp comment "Squid Proxy"
fi

# Enable and start services
echo -e "${YELLOW}Enabling and starting services...${NC}"
systemctl enable squid
systemctl start squid
systemctl enable squid-cache-warm.timer 2>/dev/null || true

# Create performance monitoring cron job
echo -e "${YELLOW}Setting up monitoring cron job...${NC}"
echo "0 */6 * * * /usr/local/bin/squid-stats >> /var/log/squid/daily-stats.log" >> /var/spool/cron/crontabs/root

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
sleep 5

if systemctl is-active --quiet squid; then
    echo -e "${GREEN}Squid is running successfully!${NC}"
else
    echo -e "${RED}Squid failed to start. Check logs: journalctl -u squid${NC}"
    exit 1
fi

# Test proxy functionality
echo -e "${YELLOW}Testing proxy functionality...${NC}"
if curl -s -x localhost:3128 http://www.google.com > /dev/null; then
    echo -e "${GREEN}Proxy test successful!${NC}"
else
    echo -e "${RED}Proxy test failed!${NC}"
fi

# Display configuration summary
echo -e "\n${GREEN}=== Squid Installation Complete! ===${NC}"
echo -e "${YELLOW}Proxy URL:${NC} http://$(hostname -I | awk '{print $1}'):3128"
echo -e "${YELLOW}Cache Directory:${NC} /var/spool/squid"
echo -e "${YELLOW}Log Files:${NC} /var/log/squid/"
echo -e "${YELLOW}Configuration:${NC} /etc/squid/squid.conf"
echo -e ""
echo -e "${YELLOW}Management Commands:${NC}"
echo -e "  squid-stats        - View cache statistics"
echo -e "  squid-bandwidth    - View bandwidth analysis"
echo -e "  squid-cleanup      - Clean and reinitialize cache"
echo -e "  systemctl restart squid - Restart proxy service"
echo -e ""
echo -e "${YELLOW}To configure clients:${NC}"
echo -e "  Set proxy server: $(hostname -I | awk '{print $1}'):3128"
echo -e "  Or configure router to use transparent proxy"
echo -e ""
echo -e "${GREEN}Cache optimization is active for:${NC}"
echo -e "  ✅ Gaming downloads (Steam, Epic, Origin)"
echo -e "  ✅ Streaming content (YouTube, Netflix, Twitch)"
echo -e "  ✅ Software updates (Windows, macOS, Linux)"
echo -e "  ✅ Web content (images, CSS, JavaScript)"
echo -e "  ✅ CDN content (Cloudflare, Akamai, etc.)"
