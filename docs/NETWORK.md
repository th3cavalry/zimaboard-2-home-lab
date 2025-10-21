# 🌐 Network Configuration

## Overview

This guide covers network setup for optimal homelab performance, especially with cellular internet connections.

---

## Router Configuration

### Recommended Setup

**Primary Router**: GL.iNet X3000 (or similar cellular router)  
**ZimaBoard IP**: 192.168.8.2 (static)  
**Network Range**: 192.168.8.0/24

### DNS Configuration

Set these DNS servers in your router:
- **Primary**: `192.168.8.2` (ZimaBoard AdGuard Home)
- **Secondary**: `1.1.1.1` (Cloudflare backup)

This enables network-wide ad-blocking for all devices.

### DHCP Reservation

Reserve IP address for ZimaBoard:
- **MAC Address**: (your ZimaBoard's MAC)
- **IP Address**: `192.168.8.2`
- **Hostname**: `zimaboard`

---

## ZimaBoard Network Setup

### Static IP Configuration

Edit the netplan configuration:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Add this configuration:

```yaml
network:
  version: 2
  ethernets:
    eth0:  # Replace with your interface name
      addresses: [192.168.8.2/24]
      gateway4: 192.168.8.1
      nameservers:
        addresses: [127.0.0.1, 1.1.1.1]
```

Apply the configuration:

```bash
sudo netplan apply
```

### Verify Network Settings

```bash
# Check IP configuration
ip addr show

# Check routing
ip route show

# Test connectivity
ping 8.8.8.8
ping 192.168.8.1
```

---

## Firewall Configuration

The installation automatically configures UFW firewall with these rules:

```bash
# View current rules
sudo ufw status verbose

# Essential ports allowed:
# 22/tcp     - SSH
# 53/tcp,udp - DNS (AdGuard Home)
# 80/tcp     - Web dashboard
# 3000/tcp   - AdGuard Home web UI
# 8000/tcp   - Nextcloud
# 3128/tcp   - Squid proxy
# 19999/tcp  - Netdata
# 51820/udp  - WireGuard VPN
```

### Custom Firewall Rules

```bash
# Allow specific IP range
sudo ufw allow from 192.168.8.0/24

# Allow specific service from anywhere
sudo ufw allow 443/tcp

# Block specific IP
sudo ufw deny from 1.2.3.4
```

---

## Bandwidth Optimization

### Squid Proxy Setup

Configure devices to use the Squid proxy for bandwidth savings:

**Proxy Server**: `192.168.8.2`  
**Port**: `3128`

#### Device Configuration

**Windows**:
1. Settings → Network & Internet → Proxy
2. Enable "Use a proxy server"
3. Address: `192.168.8.2`, Port: `3128`

**macOS**:
1. System Preferences → Network
2. Select connection → Advanced → Proxies
3. Enable "Web Proxy (HTTP)"
4. Server: `192.168.8.2`, Port: `3128`

**Android**:
1. WiFi Settings → Advanced → Proxy
2. Manual configuration
3. Hostname: `192.168.8.2`, Port: `3128`

#### Benefits

- **50-75% bandwidth savings** on cellular connections
- **Faster loading** of cached content
- **Reduced data usage** for downloads and updates

### Router QoS

Configure Quality of Service to prioritize ZimaBoard traffic:

1. **High Priority**: DNS queries (port 53)
2. **Medium Priority**: Web traffic (ports 80, 443)
3. **Low Priority**: Large downloads (proxy cache fills)

---

## VPN Access

### WireGuard Configuration

The installation creates a client configuration file:

```bash
# View client configuration
sudo cat /etc/wireguard/client.conf
```

#### Mobile Setup

1. **Install WireGuard app** on your phone
2. **Scan QR code** or import config file
3. **Connect** from anywhere

#### Desktop Setup

1. **Download config** from ZimaBoard
2. **Import** into WireGuard client
3. **Connect** for secure remote access

### Port Forwarding (Optional)

For external VPN access, configure port forwarding on your router:

- **External Port**: `51820`
- **Internal IP**: `192.168.8.2`
- **Internal Port**: `51820`
- **Protocol**: UDP

---

## Cellular Optimization

### Data Usage Monitoring

```bash
# Check interface statistics
cat /proc/net/dev

# Monitor real-time usage
iftop -i eth0

# Check Squid cache efficiency
sudo grep -E "(TCP_HIT|TCP_MISS)" /var/log/squid/access.log | tail -100
```

### Bandwidth Limits

Set monthly limits if needed:

```bash
# Monitor usage with vnstat (install if needed)
sudo apt install vnstat
vnstat -m  # Monthly usage
vnstat -d  # Daily usage
```

### Optimization Tips

1. **Enable proxy** on all devices
2. **Schedule updates** during off-peak hours
3. **Use DNS filtering** to block unnecessary traffic
4. **Monitor usage** regularly

---

## Network Troubleshooting

### Connectivity Issues

```bash
# Check network interfaces
ip link show

# Check routing table
ip route show

# Test DNS resolution
nslookup google.com 192.168.8.2

# Check service availability
curl -I http://192.168.8.2:3000
```

### Performance Issues

```bash
# Test network speed
wget -O /dev/null http://speedtest.tele2.net/100MB.zip

# Check for packet loss
ping -c 100 8.8.8.8

# Monitor network usage
iftop
nethogs
```

### DNS Issues

```bash
# Test AdGuard Home DNS
dig @192.168.8.2 google.com

# Check DNS forwarding
dig @192.168.8.2 test.local

# Flush DNS cache (if needed)
sudo systemctl restart systemd-resolved
```

---

## Advanced Configuration

### Multiple VPN Clients

Generate additional client configurations:

```bash
# Generate new client keys
wg genkey | sudo tee client2.key | wg pubkey | sudo tee client2.pub

# Add to server configuration
sudo nano /etc/wireguard/wg0.conf

# Add peer section:
[Peer]
PublicKey = CLIENT2_PUBLIC_KEY
AllowedIPs = 10.0.0.3/32
```

### VLAN Configuration (Advanced)

For network segmentation:

```bash
# Create VLAN interface
sudo ip link add link eth0 name eth0.10 type vlan id 10
sudo ip addr add 192.168.10.1/24 dev eth0.10
sudo ip link set eth0.10 up
```

### Network Monitoring

Set up automated monitoring:

```bash
# Install monitoring tools
sudo apt install nmap arp-scan

# Scan network
nmap -sn 192.168.8.0/24
arp-scan 192.168.8.0/24
```

---

## Security Considerations

### Network Hardening

1. **Change default passwords** immediately
2. **Disable unused services** 
3. **Enable firewall** with minimal rules
4. **Use strong VPN keys**
5. **Monitor access logs** regularly

### Access Control

```bash
# Limit SSH access
sudo nano /etc/ssh/sshd_config
# Add: AllowUsers your_username

# Configure fail2ban
sudo systemctl status fail2ban

# Check blocked IPs
sudo fail2ban-client status sshd
```

---

For troubleshooting network issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
