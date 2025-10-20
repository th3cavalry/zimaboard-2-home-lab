# 🔥 AdGuard Home Migration Guide

**Complete guide to migrating from Pi-hole to AdGuard Home on ZimaBoard 2**

## Why AdGuard Home?

### Key Advantages Over Pi-hole

| Feature | Pi-hole | AdGuard Home |
|---------|---------|--------------|
| **Web UI Port** | 80 (conflicts with nginx) | 3000 (no conflicts!) |
| **Admin Port** | 8080 | 3000 |
| **DNS Port** | 53 | 53 |
| **Modern UI** | Good | Excellent ⭐⭐⭐⭐⭐ |
| **Mobile Apps** | Basic | Excellent iOS/Android |
| **DNS-over-HTTPS** | Requires configuration | Built-in ✅ |
| **DNS-over-TLS** | Requires configuration | Built-in ✅ |
| **DNSCrypt** | ❌ | ✅ |
| **Per-Client Settings** | Basic | Advanced ✅ |
| **Parental Controls** | Requires blocklists | Built-in ✅ |
| **Safe Search** | ❌ | Built-in ✅ |
| **DHCP Server** | ✅ | ✅ |
| **GitHub Stars** | 48.2k | 30.5k |
| **Active Development** | ✅ | ✅ |
| **Community Support** | Huge | Large & Growing |

### Port Conflict Resolution

**Pi-hole Issue:**
- Pi-hole FTL uses port 80 for its built-in web server
- Nginx also wants port 80
- **Result**: Port conflict, nginx won't start

**AdGuard Home Solution:**
- AdGuard Home uses port 3000 for web interface
- Nginx can use port 80 without conflicts
- **Result**: Everything works perfectly! ✅

---

## Migration Process

### One-Command Migration

**Recommended method (download first):**
```bash
# SSH to your ZimaBoard
ssh username@192.168.8.2

# Download migration script
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/migrate-to-adguardhome.sh
chmod +x migrate-to-adguardhome.sh

# Run migration
sudo ./migrate-to-adguardhome.sh
```

**Alternative one-command:**
```bash
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/migrate-to-adguardhome.sh | sudo bash
```

### What the Script Does

1. **Backups Pi-hole Configuration**
   - Creates timestamped backup directory
   - Exports Pi-hole Teleporter backup
   - Saves all adlists to text file
   - Preserves custom blocklists and whitelists

2. **Removes Pi-hole Cleanly**
   - Stops Pi-hole FTL service
   - Uninstalls Pi-hole completely
   - Removes all configuration files
   - Cleans up systemd services

3. **Installs AdGuard Home**
   - Downloads latest version
   - Detects architecture automatically
   - Installs to `/opt/AdGuardHome`
   - Creates systemd service

4. **Configures AdGuard Home**
   - Sets up port 3000 for web UI
   - Configures port 53 for DNS
   - Enables DNS-over-HTTPS (Cloudflare + Google)
   - Imports default blocklists

5. **Updates System Configuration**
   - Changes nginx to port 80 (no more conflict!)
   - Updates firewall rules
   - Updates dashboard links

6. **Verifies Installation**
   - Checks service status
   - Verifies port assignments
   - Displays access URLs

---

## Post-Migration Configuration

### Initial Setup

1. **Access AdGuard Home**
   ```
   URL: http://192.168.8.2:3000
   Default Username: admin
   Default Password: admin123
   ```

2. **Change Password Immediately**
   - Click on Settings → General Settings
   - Change admin password
   - Save changes

3. **Review DNS Settings**
   - Settings → DNS Settings
   - Upstream DNS servers:
     - `https://dns.cloudflare.com/dns-query`
     - `https://dns.google/dns-query`
   - Bootstrap DNS: `1.1.1.1`, `1.0.0.1`

4. **Import Pi-hole Blocklists**
   - Your Pi-hole adlists are backed up at `/root/pihole-backup-[timestamp]/adlists.txt`
   - Go to Filters → DNS blocklists
   - Click "Add blocklist"
   - Paste each URL from your backup file
   - Or use the recommended defaults (already configured)

### Recommended Blocklists

AdGuard Home includes excellent default filters, but you can add more:

**Already Included:**
- AdGuard DNS filter (highly recommended)
- AdAway Default Blocklist

**Additional Recommended Lists:**
```
# Privacy & Tracking
https://big.oisd.nl/
https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt

# Malware Protection
https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-agh.txt

# Ads & Trackers
https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt

# YouTube Ads (limited effectiveness)
https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/youtubelist.txt
```

### Configure Router DNS

Update your GL.iNet X3000 (or other router) to use AdGuard Home:

1. Access router admin: `http://192.168.8.1`
2. Go to Network → DHCP Settings
3. Set **Primary DNS**: `192.168.8.2`
4. Set **Secondary DNS**: `1.1.1.1` (backup)
5. Save and apply

### Enable Advanced Features

**Parental Controls:**
- Settings → General Settings
- Enable "Use AdGuard browsing security web service"
- Enable "Use AdGuard parental control web service"

**Safe Search:**
- Settings → General Settings
- Enable "Enforce safe search"
- Select search engines to protect

**DNS-over-HTTPS (for clients):**
- Settings → Encryption Settings
- Enable "HTTPS"
- Access via: `https://192.168.8.2/dns-query`

**Per-Client Settings:**
- Clients tab
- Click on a client
- Set custom rules, blocking schedules, etc.

---

## Port Assignments After Migration

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| **Nginx** | 80 | `http://192.168.8.2` | Dashboard (no more conflict!) |
| **AdGuard Home** | 3000 | `http://192.168.8.2:3000` | DNS admin interface |
| **AdGuard DNS** | 53 | - | DNS server |
| **Nextcloud** | 8000 | `http://192.168.8.2:8000` | Personal cloud |
| **Netdata** | 19999 | `http://192.168.8.2:19999` | System monitoring |
| **WireGuard** | 51820 (UDP) | - | VPN server |

---

## Troubleshooting

### AdGuard Home Won't Start

```bash
# Check service status
sudo systemctl status AdGuardHome

# Check logs
sudo journalctl -u AdGuardHome -n 100

# Restart service
sudo systemctl restart AdGuardHome
```

### DNS Not Working

```bash
# Test DNS resolution
nslookup google.com 192.168.8.2

# Check if port 53 is listening
sudo ss -tulnp | grep :53

# Restart AdGuard Home
sudo systemctl restart AdGuardHome
```

### Web Interface Not Accessible

```bash
# Check if port 3000 is listening
sudo ss -tulnp | grep :3000

# Check firewall
sudo ufw status | grep 3000

# Allow port if needed
sudo ufw allow 3000/tcp
```

### Restore Pi-hole Backup

If you want to revert to Pi-hole:

```bash
# Find your backup
ls -la /root/pihole-backup-*

# Reinstall Pi-hole
curl -sSL https://install.pi-hole.net | bash

# Restore from backup
pihole -a -t /root/pihole-backup-[timestamp]/pihole-backup.tar.gz
```

---

## Performance Comparison

### Resource Usage

| Metric | Pi-hole | AdGuard Home |
|--------|---------|--------------|
| **RAM Usage** | ~200MB | ~100-150MB |
| **CPU Usage** | Low | Low |
| **Disk I/O** | Moderate | Low |
| **Query Speed** | Fast | Fast |
| **Startup Time** | ~5s | ~2s |

### Features Comparison

| Feature | Pi-hole | AdGuard Home | Winner |
|---------|---------|--------------|--------|
| Port Conflict | Yes ⚠️ | No ✅ | AdGuard |
| Setup Complexity | Medium | Easy | AdGuard |
| Mobile App | Basic | Excellent | AdGuard |
| DNS Encryption | Manual | Built-in | AdGuard |
| UI Design | Good | Excellent | AdGuard |
| Community Size | Huge | Large | Pi-hole |
| Documentation | Excellent | Good | Tie |

---

## Advanced Configuration

### Custom Upstream DNS

```yaml
# Edit /var/lib/AdGuardHome/AdGuardHome.yaml
upstream_dns:
  - https://dns.cloudflare.com/dns-query
  - https://dns.google/dns-query
  - tls://dns.quad9.net
  - https://dns.adguard.com/dns-query
```

### Enable Query Logging

```yaml
querylog:
  enabled: true
  file_enabled: true
  interval: 2160h  # 90 days
  size_memory: 1000
```

### Client-Specific Rules

```yaml
clients:
  persistent:
    - name: "Kids iPad"
      ids:
        - 192.168.8.100
      use_global_settings: false
      filtering_enabled: true
      parental_enabled: true
      safebrowsing_enabled: true
```

### Custom DNS Rewrites

```yaml
dns:
  rewrites:
    - domain: "homelab.local"
      answer: "192.168.8.2"
    - domain: "nextcloud.local"
      answer: "192.168.8.2"
```

---

## Maintenance

### Update AdGuard Home

```bash
# Check for updates in web UI
# Or command line:
cd /opt/AdGuardHome
sudo ./AdGuardHome --update
sudo systemctl restart AdGuardHome
```

### Backup Configuration

```bash
# Backup configuration
sudo cp /var/lib/AdGuardHome/AdGuardHome.yaml /root/adguard-backup-$(date +%Y%m%d).yaml

# Backup with script
sudo tar -czf /root/adguard-full-backup-$(date +%Y%m%d).tar.gz /var/lib/AdGuardHome/
```

### View Statistics

```bash
# Via web UI: http://192.168.8.2:3000

# Or via API:
curl -u admin:password http://192.168.8.2:3000/control/stats
```

---

## FAQ

**Q: Can I run both Pi-hole and AdGuard Home?**
A: No, they both use port 53 for DNS and would conflict.

**Q: Will my devices need reconfiguration?**
A: No, if they're using DHCP, they'll automatically get the new DNS server (192.168.8.2 stays the same).

**Q: Can I migrate back to Pi-hole?**
A: Yes, your Pi-hole configuration is backed up in `/root/pihole-backup-[timestamp]/`

**Q: Does AdGuard Home work with WireGuard VPN?**
A: Yes, perfectly! No configuration changes needed.

**Q: What about my custom Pi-hole blocklists?**
A: They're saved in your backup. Add them manually in AdGuard Home's Filters section.

**Q: Is AdGuard Home as effective as Pi-hole?**
A: Yes, equally effective at blocking ads and trackers. Some say AdGuard's filters are even better.

**Q: Will this break my network?**
A: No, the migration script is safe and backs up everything first. DNS continues to work throughout the process.

---

## Additional Resources

- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [AdGuard Home GitHub](https://github.com/AdguardTeam/AdGuardHome)
- [Community Forum](https://github.com/AdguardTeam/AdGuardHome/discussions)
- [Filter Lists](https://filterlists.com/)
- [AdGuard DNS KB](https://adguard-dns.io/kb/)

---

## Support

If you encounter any issues during migration:

1. Check the troubleshooting section above
2. Review the migration script logs
3. Check AdGuard Home logs: `sudo journalctl -u AdGuardHome`
4. Open an issue on our GitHub repo
5. Consult AdGuard Home's official documentation

---

**Happy DNS filtering with AdGuard Home! 🎉**
