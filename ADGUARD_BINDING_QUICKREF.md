# Quick Reference: AdGuard Home 0.0.0.0 Binding Fix

## The Issue
The AdGuard Home web setup wizard doesn't provide an option to manually enter `0.0.0.0` for interface binding. It only shows specific IP addresses, which can prevent proper network-wide access.

## The Solution
This repository includes a **pre-configured `AdGuardHome.yaml`** file that automatically binds to `0.0.0.0` (all interfaces).

## For Docker Users (Path A)

### Quick Start
```bash
cd ~/zimaboard-2-home-lab
docker compose up -d
```

The pre-configured file is automatically mounted and used. Just:
1. Navigate to `http://YOUR-IP:3000`
2. Create admin username and password
3. Done! Binding is already set to `0.0.0.0`

### File Location
- **Template**: `configs/adguardhome/AdGuardHome.yaml`
- **Mount Point**: `/opt/adguardhome/conf/AdGuardHome.yaml` (inside container)

## For Bare-Metal Users (Path B)

### Option 1: Before First Setup (Recommended)
```bash
sudo systemctl stop AdGuardHome
sudo curl -o /opt/AdGuardHome/AdGuardHome.yaml \
  https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/configs/adguardhome/AdGuardHome.yaml
sudo systemctl start AdGuardHome
```

### Option 2: After Setup (Manual Edit)
```bash
sudo systemctl stop AdGuardHome
sudo nano /opt/AdGuardHome/AdGuardHome.yaml
# Change: bind_host: 0.0.0.0
# Change: dns.bind_hosts: [0.0.0.0]
sudo systemctl start AdGuardHome
```

## Configuration Details

The pre-configured file includes:

| Setting | Value |
|---------|-------|
| **Web Interface** | `0.0.0.0:3000` |
| **DNS Server** | `0.0.0.0:53` |
| **Upstream DNS** | Cloudflare (1.1.1.1, 1.0.0.1)<br>Google (8.8.8.8, 8.8.4.4) |
| **DNS Blocklists** | AdGuard DNS filter<br>AdAway Default Blocklist |
| **Cache Size** | 4 MB (4,194,304 entries) |
| **Rate Limiting** | 20 queries/sec per client |

## Verification

Check if AdGuard Home is listening on all interfaces:
```bash
# Should show 0.0.0.0:3000
sudo ss -tulpn | grep :3000
sudo ss -tulpn | grep :53
```

## Why 0.0.0.0?

Binding to `0.0.0.0` means "listen on ALL network interfaces":
- ✅ Local access (`127.0.0.1`)
- ✅ Docker network (`172.20.0.x`)
- ✅ LAN access (`192.168.x.x`)
- ✅ Maximum flexibility

## Troubleshooting

### Can't Access Web Interface
```bash
# For Docker:
docker compose restart adguard
docker compose logs adguard

# For Bare-Metal:
sudo systemctl restart AdGuardHome
sudo journalctl -u AdGuardHome -n 50
```

### Port 53 Conflict
```bash
# Disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

## Additional Resources

- Full documentation: `README.md`
- Config README: `configs/adguardhome/README.md`
- Bare-metal guide: `bare-metal/ADGUARD_BINDING_FIX.md`

---

**Created**: 2025-10-22  
**Issue**: Cannot set bind to 0.0.0.0  
**Repository**: th3cavalry/zimaboard-2-home-lab
