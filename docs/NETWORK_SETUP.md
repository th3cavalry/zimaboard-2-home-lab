# Network Configuration Guide

## Overview

This guide explains how to configure your ZimaBoard 2 homelab with the GL.iNet X3000 cellular router for optimal security and performance.

## Network Topology

```
Internet (Cellular) 
    ↓
GL.iNet X3000 Router (192.168.8.1)
    ↓ (Ethernet)
ZimaBoard 2 (192.168.8.100)
    ↓ (WiFi)
Client Devices (192.168.8.0/24)
```

## GL.iNet X3000 Configuration

### 1. Basic Network Setup

1. **Access GL.iNet Admin Panel**
   - Connect to: `http://192.168.8.1`
   - Default credentials: admin/password (change immediately)

2. **Configure LAN Settings**
   - LAN IP: `192.168.8.1`
   - Subnet Mask: `255.255.255.0` (/24)
   - DHCP Range: `192.168.8.101-192.168.8.200`
   - DHCP Lease Time: 24 hours

3. **Reserve IP for ZimaBoard**
   - Go to Network → LAN → DHCP Reservations
   - Add reservation:
     - MAC Address: [ZimaBoard's MAC]
     - IP Address: `192.168.8.100`
     - Name: `ZimaBoard-2-Homelab`

### 2. DNS Configuration

1. **Primary DNS Settings**
   - Primary DNS: `192.168.8.100` (ZimaBoard Pi-hole)
   - Secondary DNS: `1.1.1.1` (Cloudflare - fallback)
   - DNS Rebind Protection: Disable
   - DNS Hijacking: Enable (redirect all DNS to ZimaBoard)

2. **Advanced DNS Options**
   - Force all DNS queries through Pi-hole
   - Block DNS over HTTPS/TLS on port 853
   - Enable DNS logging for monitoring

### 3. Security Settings

1. **Firewall Configuration**
   ```
   WAN → LAN: Block (except established connections)
   LAN → WAN: Allow
   LAN → DMZ: Allow to ZimaBoard only
   ```

2. **Port Forwarding** (Optional - for remote access)
   ```
   External Port 8080 → 192.168.8.100:8080 (Pi-hole)
   External Port 9000 → 192.168.8.100:9000 (Portainer)
   External Port 3000 → 192.168.8.100:3000 (Grafana)
   ```

3. **Access Control**
   - Enable MAC address filtering
   - Set up guest network isolation
   - Configure bandwidth limits per device

## ZimaBoard 2 Network Configuration

### 1. Static IP Configuration

```bash
# Configure static IP using NetworkManager
sudo nmcli con mod "Wired connection 1" \
    ipv4.addresses "192.168.8.100/24" \
    ipv4.gateway "192.168.8.1" \
    ipv4.dns "127.0.0.1,1.1.1.1" \
    ipv4.method manual

# Apply changes
sudo nmcli con up "Wired connection 1"

# Verify configuration
ip addr show
ip route show
```

### 2. Network Interface Optimization

```bash
# Create network optimization script
sudo tee /etc/systemd/system/network-optimize.service << 'EOL'
[Unit]
Description=Network optimization for homelab
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/optimize-network.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

# Create optimization script
sudo tee /usr/local/bin/optimize-network.sh << 'EOL'
#!/bin/bash
# Optimize network settings for security monitoring

# Increase network buffers
echo 16777216 > /proc/sys/net/core/rmem_max
echo 16777216 > /proc/sys/net/core/wmem_max
echo 2048 > /proc/sys/net/core/netdev_max_backlog

# Enable packet forwarding (for monitoring)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Optimize TCP settings
echo 'bbr' > /proc/sys/net/ipv4/tcp_congestion_control
echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing

# Security settings
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
EOL

sudo chmod +x /usr/local/bin/optimize-network.sh
sudo systemctl enable network-optimize.service
sudo systemctl start network-optimize.service
```

### 3. DNS Resolution Setup

```bash
# Configure systemd-resolved
sudo tee /etc/systemd/resolved.conf << 'EOL'
[Resolve]
DNS=127.0.0.1
FallbackDNS=1.1.1.1 1.0.0.1
Domains=~.
DNSSEC=yes
DNSOverTLS=no
Cache=yes
DNSStubListener=no
EOL

# Restart resolved
sudo systemctl restart systemd-resolved

# Link resolv.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

## Client Device Configuration

### Automatic Configuration (Recommended)

1. **DHCP-based** (easiest):
   - Devices receive ZimaBoard IP as DNS automatically
   - No manual configuration required
   - Works for all device types

### Manual Configuration

1. **Windows 10/11**:
   ```
   Settings → Network & Internet → Ethernet/WiFi → Properties
   IP assignment: Automatic (DHCP)
   DNS server assignment: Manual
   Preferred DNS: 192.168.8.100
   Alternate DNS: 1.1.1.1
   ```

2. **macOS**:
   ```
   System Preferences → Network → WiFi/Ethernet → Advanced → DNS
   DNS Servers: 192.168.8.100, 1.1.1.1
   ```

3. **iOS/Android**:
   ```
   WiFi Settings → Modify Network → Advanced Options
   IP Settings: DHCP
   DNS: 192.168.8.100,1.1.1.1
   ```

4. **Linux**:
   ```bash
   sudo nmcli con mod "WiFi-Network" ipv4.dns "192.168.8.100,1.1.1.1"
   sudo nmcli con up "WiFi-Network"
   ```

## Network Monitoring

### 1. Traffic Analysis

Monitor network traffic with built-in tools:

```bash
# View real-time network statistics
sudo docker exec -it suricata suricata-update list-sources

# Check DNS query logs
sudo docker exec -it pihole tail -f /var/log/pihole.log

# Monitor bandwidth usage
sudo docker exec -it prometheus curl -s http://localhost:9090/metrics | grep network
```

### 2. Performance Testing

```bash
# Test DNS resolution speed
dig @192.168.8.100 google.com +stats

# Test internet connectivity
ping -c 4 8.8.8.8

# Test bandwidth
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

## Troubleshooting

### Common Issues

1. **No Internet Access**:
   ```bash
   # Check network connectivity
   ping 192.168.8.1  # Gateway
   ping 8.8.8.8      # External DNS
   
   # Check DNS resolution
   nslookup google.com 192.168.8.100
   ```

2. **Slow DNS Resolution**:
   ```bash
   # Clear DNS cache
   sudo docker exec -it pihole pihole restartdns
   sudo docker exec -it unbound unbound-control flush_zone .
   ```

3. **Blocked Websites**:
   ```bash
   # Check Pi-hole logs
   sudo docker exec -it pihole tail -f /var/log/pihole.log
   
   # Temporarily disable Pi-hole
   sudo docker exec -it pihole pihole disable 5m
   ```

### Network Diagnostics

```bash
# Comprehensive network test script
cat > test-network.sh << 'EOL'
#!/bin/bash
echo "=== Network Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "1. Network Interfaces:"
ip addr show | grep -E "(inet |state )"
echo ""

echo "2. Routing Table:"
ip route show
echo ""

echo "3. DNS Resolution Test:"
nslookup google.com 192.168.8.100
echo ""

echo "4. Connectivity Tests:"
ping -c 3 192.168.8.1 && echo "Gateway: OK" || echo "Gateway: FAIL"
ping -c 3 8.8.8.8 && echo "Internet: OK" || echo "Internet: FAIL"
echo ""

echo "5. Service Status:"
docker-compose ps
echo ""

echo "6. Pi-hole Status:"
curl -s "http://192.168.8.100:8080/admin/api.php" | jq '.status' || echo "Pi-hole API: FAIL"
EOL

chmod +x test-network.sh
./test-network.sh
```

## Security Considerations

1. **Change Default Passwords**:
   - GL.iNet admin password
   - Pi-hole web password
   - All homelab service passwords

2. **Enable Firewall**:
   - Block unnecessary ports
   - Enable intrusion detection
   - Monitor failed login attempts

3. **Regular Updates**:
   - GL.iNet firmware
   - ZimaBoard system updates
   - Docker images and security definitions

4. **Access Logging**:
   - Enable comprehensive logging
   - Monitor access patterns
   - Set up alerting for suspicious activity

## Advanced Configuration

### VPN Access

Set up VPN for remote homelab access:

```bash
# Install WireGuard on ZimaBoard
sudo apt install wireguard

# Generate keys
wg genkey | tee privatekey | wg pubkey > publickey

# Configure WireGuard server
sudo tee /etc/wireguard/wg0.conf << 'EOL'
[Interface]
PrivateKey = [SERVER_PRIVATE_KEY]
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = [CLIENT_PUBLIC_KEY]
AllowedIPs = 10.0.0.2/32
EOL

# Start WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

### Load Balancing

For high-availability setups:

```bash
# Configure multiple DNS servers
# Add backup Pi-hole instance
# Implement automatic failover
```

---

This network setup provides a robust, secure foundation for your ZimaBoard 2 homelab with comprehensive monitoring and protection capabilities.
