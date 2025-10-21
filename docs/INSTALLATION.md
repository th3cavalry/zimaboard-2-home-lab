# 📦 Installation Guide

## Prerequisites

### Hardware Requirements

- **ZimaBoard 2** (8GB RAM minimum, 16GB recommended)
- **64GB eMMC** (standard with ZimaBoard 2)
- **2TB+ SSD** (highly recommended for data storage)
- **Network connection** (Ethernet recommended)

### Software Requirements

- **Ubuntu Server 24.04 LTS** (freshly installed)
- **Root access** (sudo privileges)
- **Internet connection** (for package downloads)

---

## Quick Installation

### One-Command Setup

```bash
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
```

### Recommended Method (Download First)

```bash
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

---

## Manual Installation

If you prefer to understand each step:

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git htop
```

### 2. Storage Setup

The installer will automatically detect and offer to configure your SSD:

- **Format fresh** (recommended for new drives)
- **Use existing partitions** (preserves data)
- **Advanced setup** (manual configuration)
- **Skip SSD** (eMMC only - not recommended)

### 3. Service Installation

Services are installed in this order:

1. **System optimizations** (eMMC longevity)
2. **AdGuard Home** (DNS filtering)
3. **Nginx** (web server & reverse proxy)
4. **Nextcloud** (personal cloud)
5. **WireGuard** (VPN server)
6. **Squid** (bandwidth optimization)
7. **Netdata** (system monitoring)

---

## Post-Installation

### Initial Configuration

1. **Change default passwords**:
   - AdGuard Home: http://192.168.8.2:3000 (admin/admin123)
   - Nextcloud: http://192.168.8.2:8000 (admin/admin123)

2. **Configure router DNS**:
   - Set primary DNS to `192.168.8.2`

3. **Download VPN config**:
   ```bash
   sudo cat /etc/wireguard/client.conf
   ```

### Verification

Check that all services are running:

```bash
sudo systemctl status AdGuardHome
sudo systemctl status nginx
sudo systemctl status mariadb
sudo systemctl status wg-quick@wg0
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.
