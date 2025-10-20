# 🛠️ Service Management

## Service Overview

| Service | Port | Status | Purpose |
|---------|------|--------|---------|
| **AdGuard Home** | 3000 | Core | DNS filtering & ad-blocking |
| **Nextcloud** | 8000 | Core | Personal cloud & office suite |
| **Nginx** | 80 | Core | Web server & reverse proxy |
| **WireGuard** | 51820 | Core | VPN server |
| **Squid** | 3128 | Optimization | Bandwidth caching |
| **Netdata** | 19999 | Monitoring | System metrics |
| **MariaDB** | 3306 | Database | Nextcloud database |
| **Redis** | 6379 | Cache | Nextcloud caching |

---

## Service Management Commands

### Check Service Status

```bash
# Check all core services
sudo systemctl status AdGuardHome nginx mariadb wg-quick@wg0

# Check individual service
sudo systemctl status nextcloud
```

### Start/Stop/Restart Services

```bash
# Restart a service
sudo systemctl restart AdGuardHome

# Stop a service
sudo systemctl stop squid

# Start a service
sudo systemctl start netdata
```

### View Service Logs

```bash
# View recent logs
sudo journalctl -u AdGuardHome --since "1 hour ago"

# Follow logs in real-time
sudo journalctl -u nginx -f
```

---

## Individual Service Configuration

### AdGuard Home

**Location**: http://192.168.8.2:3000  
**Config**: `/opt/AdGuardHome/AdGuardHome.yaml`  
**Data**: `/mnt/ssd-data/adguardhome` (if SSD available)

```bash
# Restart AdGuard Home
sudo systemctl restart AdGuardHome

# View configuration
sudo cat /opt/AdGuardHome/AdGuardHome.yaml

# Check DNS functionality
nslookup google.com 192.168.8.2
```

### Nextcloud

**Location**: http://192.168.8.2:8000  
**Config**: `/var/www/nextcloud/config/config.php`  
**Data**: `/mnt/ssd-data/nextcloud` (if SSD available)

```bash
# Nextcloud commands
cd /var/www/nextcloud
sudo -u www-data php occ status
sudo -u www-data php occ user:list

# Restart Nextcloud services
sudo systemctl restart mariadb
sudo systemctl restart php*-fpm
sudo systemctl restart redis-server
```

### WireGuard VPN

**Config**: `/etc/wireguard/wg0.conf`  
**Client Config**: `/etc/wireguard/client.conf`

```bash
# Check VPN status
sudo wg show

# Restart VPN
sudo systemctl restart wg-quick@wg0

# Generate new client config
sudo wg genkey | tee client2.key | wg pubkey > client2.pub
```

### Nginx

**Config**: `/etc/nginx/sites-available/homelab`  
**Web Root**: `/var/www/html`

```bash
# Test configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Check access logs
sudo tail -f /var/log/nginx/access.log
```

### Squid Proxy

**Config**: `/etc/squid/squid.conf`  
**Cache**: `/mnt/ssd-data/squid-cache` (if SSD available)

```bash
# Check cache usage
sudo du -sh /mnt/ssd-data/squid-cache

# Clear cache
sudo squid -k reconfigure

# View access logs
sudo tail -f /var/log/squid/access.log
```

### Netdata

**Location**: http://192.168.8.2:19999  
**Config**: `/etc/netdata/netdata.conf`

```bash
# Restart netdata
sudo systemctl restart netdata

# Check configuration
sudo /usr/sbin/netdata -W set 2>/dev/null
```

---

## Backup & Restore

### Create Backup

```bash
# Manual backup script (if available)
sudo /opt/homelab/scripts/backup.sh

# Or manual backup
sudo tar -czf /mnt/ssd-backup/homelab-backup-$(date +%Y%m%d).tar.gz \
    /etc/wireguard/ \
    /opt/AdGuardHome/ \
    /var/www/nextcloud/config/ \
    /etc/nginx/sites-available/homelab
```

### Database Backup

```bash
# Backup Nextcloud database
sudo mysqldump -u root -p nextcloud > /mnt/ssd-backup/nextcloud-db-$(date +%Y%m%d).sql
```

---

## Performance Monitoring

### System Resources

```bash
# Check memory usage
free -h

# Check disk usage
df -h

# Check service resource usage
htop
```

### Service-Specific Monitoring

```bash
# AdGuard Home query stats
curl -s http://192.168.8.2:3000/control/stats

# Nextcloud status
cd /var/www/nextcloud
sudo -u www-data php occ status

# Network connections
sudo ss -tlnp
```

---

## Troubleshooting

### Common Issues

1. **Service won't start**: Check logs with `journalctl -u SERVICE_NAME`
2. **Port conflicts**: Check with `sudo ss -tlnp | grep PORT`
3. **Permission issues**: Verify file ownership and permissions
4. **Database issues**: Check MariaDB status and logs

### Emergency Recovery

```bash
# Stop all services
sudo systemctl stop AdGuardHome nginx mariadb wg-quick@wg0 squid netdata

# Start services one by one
sudo systemctl start mariadb
sudo systemctl start AdGuardHome
# ... etc
```

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
