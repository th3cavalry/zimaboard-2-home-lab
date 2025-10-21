# 🔧 Troubleshooting Guide

## Quick Diagnostics

### System Health Check

```bash
# Check all core services
sudo systemctl status AdGuardHome nginx mariadb wg-quick@wg0 squid netdata

# Check system resources
free -h && df -h

# Check network connectivity
ping -c 3 8.8.8.8
```

### Port Status Check

```bash
# Check all listening ports
sudo ss -tlnp

# Check specific service ports
sudo ss -tlnp | grep -E ':(80|3000|8000|19999|51820|3128)'
```

---

## Common Issues

### 1. Service Won't Start

**Symptoms**: Service fails to start or keeps restarting

**Diagnosis**:
```bash
# Check service status
sudo systemctl status SERVICE_NAME

# Check logs
sudo journalctl -u SERVICE_NAME --since "10 minutes ago"

# Check for port conflicts
sudo ss -tlnp | grep PORT_NUMBER
```

**Solutions**:
- Check configuration file syntax
- Verify file permissions
- Ensure no port conflicts
- Check disk space availability

### 2. Can't Access Web Interfaces

**Symptoms**: 
- Can't reach http://192.168.8.2:3000 (AdGuard Home)
- Can't reach http://192.168.8.2:8000 (Nextcloud)
- Can't reach http://192.168.8.2 (Dashboard)

**Diagnosis**:
```bash
# Check nginx status
sudo systemctl status nginx

# Check if ports are listening
sudo ss -tlnp | grep -E ':(80|3000|8000)'

# Test local connectivity
curl -I http://localhost:3000
curl -I http://localhost:8000
```

**Solutions**:
```bash
# Restart nginx
sudo systemctl restart nginx

# Check firewall
sudo ufw status

# Verify nginx configuration
sudo nginx -t
```

### 3. AdGuard Home Issues

**Symptoms**: DNS queries not working, web interface inaccessible

**Diagnosis**:
```bash
# Test DNS resolution
nslookup google.com 192.168.8.2
dig @192.168.8.2 google.com

# Check AdGuard Home logs
sudo journalctl -u AdGuardHome --since "1 hour ago"
```

**Solutions**:
```bash
# Restart AdGuard Home
sudo systemctl restart AdGuardHome

# Check configuration
sudo /opt/AdGuardHome/AdGuardHome --check-config

# Reconfigure if needed
sudo /opt/AdGuardHome/AdGuardHome -s stop
sudo /opt/AdGuardHome/AdGuardHome -s start
```

### 4. Nextcloud Problems

**Symptoms**: 
- White screen or 500 errors
- Database connection issues
- File upload failures

**Diagnosis**:
```bash
# Check Nextcloud status
cd /var/www/nextcloud
sudo -u www-data php occ status

# Check database connection
sudo systemctl status mariadb

# Check PHP-FPM
sudo systemctl status php*-fpm

# Check Nextcloud logs
sudo tail -f /var/www/nextcloud/data/nextcloud.log
```

**Solutions**:
```bash
# Restart all Nextcloud services
sudo systemctl restart mariadb
sudo systemctl restart php*-fpm
sudo systemctl restart redis-server
sudo systemctl restart nginx

# Fix permissions
sudo chown -R www-data:www-data /var/www/nextcloud
sudo chown -R www-data:www-data /mnt/ssd-data/nextcloud

# Update trusted domains
sudo -u www-data php occ config:system:set trusted_domains 1 --value="192.168.8.2"
```

### 5. VPN Connection Issues

**Symptoms**: Can't connect to WireGuard VPN

**Diagnosis**:
```bash
# Check WireGuard status
sudo wg show
sudo systemctl status wg-quick@wg0

# Check firewall rules
sudo iptables -L -n | grep 51820
sudo ufw status | grep 51820
```

**Solutions**:
```bash
# Restart WireGuard
sudo systemctl restart wg-quick@wg0

# Check configuration
sudo cat /etc/wireguard/wg0.conf

# Verify IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should show 1
```

### 6. Storage Issues

**Symptoms**: 
- Services failing due to disk space
- SSD not detected
- Performance issues

**Diagnosis**:
```bash
# Check disk usage
df -h

# Check SSD mount status
mount | grep ssd
lsblk

# Check for filesystem errors
sudo dmesg | grep -i error
```

**Solutions**:
```bash
# Clean up logs if space is low
sudo journalctl --vacuum-time=7d

# Remount SSD if unmounted
sudo mount -a

# Check SSD health
sudo smartctl -a /dev/sda  # Replace with your SSD device
```

### 7. Performance Issues

**Symptoms**: 
- Slow response times
- High memory usage
- System sluggishness

**Diagnosis**:
```bash
# Check system resources
htop
iotop -a

# Check service memory usage
ps aux --sort=-%mem | head -10

# Check system load
uptime
```

**Solutions**:
```bash
# Restart memory-heavy services
sudo systemctl restart mariadb
sudo systemctl restart php*-fpm

# Clear caches
sudo sync && echo 3 > /proc/sys/vm/drop_caches

# Check for runaway processes
top -o %MEM
```

---

## Network Issues

### Router DNS Configuration

If network-wide ad-blocking isn't working:

1. **Router DNS Settings**:
   - Set primary DNS to `192.168.8.2`
   - Set secondary DNS to `1.1.1.1` (backup)

2. **Test DNS Resolution**:
   ```bash
   # From another device on the network
   nslookup google.com
   # Should show server as 192.168.8.2
   ```

### Squid Proxy Issues

If bandwidth optimization isn't working:

```bash
# Check squid status
sudo systemctl status squid

# Check access logs
sudo tail -f /var/log/squid/access.log

# Test proxy connection
curl -x http://192.168.8.2:3128 http://example.com
```

---

## Emergency Recovery

### Complete Service Restart

```bash
# Stop all services
sudo systemctl stop AdGuardHome nginx mariadb wg-quick@wg0 squid netdata redis-server

# Wait a moment
sleep 5

# Start services in order
sudo systemctl start mariadb
sudo systemctl start redis-server
sudo systemctl start AdGuardHome
sudo systemctl start nginx
sudo systemctl start wg-quick@wg0
sudo systemctl start squid
sudo systemctl start netdata
```

### Reset to Defaults

If you need to completely reset:

```bash
# Use the uninstall script (if available)
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/uninstall.sh | sudo bash

# Then reinstall
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
```

---

## Getting Help

### Collect System Information

Before asking for help, collect this information:

```bash
# System info
uname -a
lsb_release -a

# Service status
sudo systemctl status AdGuardHome nginx mariadb --no-pager

# Resource usage
free -h
df -h

# Network configuration
ip addr show
ip route show
```

### Log Collection

```bash
# Recent system logs
sudo journalctl --since "1 hour ago" > system-logs.txt

# Service-specific logs
sudo journalctl -u AdGuardHome --since "1 hour ago" > adguard-logs.txt
sudo journalctl -u nginx --since "1 hour ago" > nginx-logs.txt
```

### Support Channels

- **GitHub Issues**: [Report a bug](https://github.com/th3cavalry/zimaboard-2-home-lab/issues/new)
- **Discussions**: [Ask questions](https://github.com/th3cavalry/zimaboard-2-home-lab/discussions)
- **ZimaBoard Community**: [Hardware-specific help](https://community.zimaspace.com/)

---

## Prevention

### Regular Maintenance

```bash
# Weekly system updates
sudo apt update && sudo apt upgrade -y

# Monthly log cleanup
sudo journalctl --vacuum-time=30d

# Check disk space regularly
df -h

# Monitor service health
sudo systemctl status AdGuardHome nginx mariadb
```

### Backup Strategy

- **Automatic backups**: Set up regular configuration backups
- **Database backups**: Schedule weekly database dumps
- **Configuration snapshots**: Before making changes
