# 🚀 GL.iNet X3000 Quick Reference Card

## 📱 Essential Access Information

| Item | Value |
|------|-------|
| **Admin URL** | `http://192.168.8.1` |
| **Default Login** | `admin` / `admin` |
| **WiFi SSID** | `GL-X3000-XXX` (check device label) |
| **WiFi Password** | `goodlife` (default) |
| **LAN IP Range** | `192.168.8.1/24` |
| **ZimaBoard IP** | `192.168.8.2` (recommended) |

## ⚡ Quick Setup Commands

### **1. ZimaBoard Static IP Setup:**
```bash
# SSH into ZimaBoard and run:
nmcli con mod "Wired connection 1" ipv4.addresses "192.168.8.2/24"
nmcli con mod "Wired connection 1" ipv4.gateway "192.168.8.1"
nmcli con mod "Wired connection 1" ipv4.dns "127.0.0.1"
nmcli con mod "Wired connection 1" ipv4.method manual
nmcli con up "Wired connection 1"
```

### **2. Verify Connectivity:**
```bash
ping 192.168.8.1    # X3000 gateway
ping 8.8.8.8        # Internet
curl http://192.168.8.100/admin  # Pi-hole test
```

## 🎯 Critical X3000 Settings

### **DNS Configuration:**
- **Primary DNS**: `192.168.8.100` (Pi-hole)
- **Secondary DNS**: `1.1.1.1` (backup)
- **DNS Rebinding Protection**: **DISABLED**

### **DHCP Reservation:**
- **MAC**: ZimaBoard MAC address
- **IP**: `192.168.8.2`
- **Hostname**: `zimaboard`

### **APN Settings by Carrier:**
| Carrier | APN |
|---------|-----|
| **Verizon** | `vzwinternet` |
| **AT&T** | `broadband` or `phone` |
| **T-Mobile** | `fast.t-mobile.com` |
| **Mint Mobile** | `wholesale` |
| **Visible** | `vsblinternet` |

## 🛡️ Security Essentials

### **Must-Do Security Steps:**
1. **Change admin password** immediately
2. **Disable WPS** on WiFi
3. **Enable WPA3** security (or WPA2 minimum)
4. **Disable remote management** unless needed
5. **Set strong WiFi password** (20+ characters)

### **Firewall Rules:**
- **LAN to WAN**: ✅ Allow
- **WAN to LAN**: ❌ Block (except port forwards)
- **SPI Firewall**: ✅ Enable
- **DoS Protection**: ✅ Enable

## 📊 Performance Optimization

### **QoS Settings:**
- **Smart QoS**: ✅ Enable
- **Gaming Mode**: ✅ Enable (low latency)
- **ZimaBoard Priority**: 🔥 High
- **Bandwidth Limit**: 80% of plan speed

### **Cellular Optimization:**
- **Network Mode**: 5G/4G Auto
- **Band Selection**: Auto (or lock best bands)
- **MIMO**: ✅ Enable
- **Carrier Aggregation**: ✅ Enable

## 🔧 Port Forwarding (Optional)

### **Common Service Ports:**
| Service | Internal | External | Protocol |
|---------|----------|----------|----------|
| **Proxmox** | `192.168.8.2:8006` | `8006` | TCP |
| **Pi-hole** | `192.168.8.100/admin` | `8080` | TCP |
| **Seafile** | `192.168.8.101:8000` | `8000` | TCP |
| **Wireguard** | `192.168.8.102:51820` | `51820` | UDP |
| **SSH** | `192.168.8.2:22` | `2222` | TCP |

### **DMZ Alternative:**
- **DMZ Host**: `192.168.8.2`
- **⚠️ Security Risk**: Exposes all ports

## 📱 WiFi Configuration

### **Primary Network:**
- **SSID**: `HomeNet-Secure`
- **Security**: WPA3-SAE (preferred) or WPA2-PSK
- **Band**: 5GHz (speed) + 2.4GHz (range)
- **Channel Width**: 80MHz (5GHz), 40MHz (2.4GHz)

### **Guest Network:**
- **SSID**: `HomeNet-Guest`
- **Bandwidth**: 50% of main network
- **Isolation**: ✅ Enable
- **Time Restriction**: Optional

## 🚨 Troubleshooting Quick Fixes

### **No Internet:**
```bash
# Check connection status
ping 192.168.8.1     # X3000 gateway
ping 8.8.8.8         # Internet test
ip route show        # Check routing
```

### **DNS Issues:**
```bash
# Test Pi-hole DNS
nslookup google.com 192.168.8.100
nslookup ads.google.com 192.168.8.100  # Should be blocked
```

### **Slow Performance:**
1. Check **signal strength** in X3000 admin
2. Verify **QoS settings** are optimized
3. Check **data usage** isn't at limit
4. Test **speed with/without Squid proxy**

### **Can't Access Services:**
1. Check **ZimaBoard services**: `pct list`
2. Verify **firewall rules** on X3000
3. Test **local access first**: `curl http://192.168.8.100/admin`
4. Check **port forwarding** configuration

## 📊 Monitoring Dashboard

### **Key Metrics to Watch:**
- **Signal Strength**: >-80dBm (good), >-70dBm (excellent)
- **Data Usage**: Track monthly consumption
- **Connection Uptime**: Should be >99%
- **Temperature**: <60°C optimal

### **Regular Maintenance:**
- 🔄 **Monthly reboot** for optimal performance
- 📊 **Check data usage** weekly
- 🔧 **Update firmware** when available
- 📡 **Verify antenna connections** monthly

## 🎯 Integration Benefits

**With ZimaBoard Homelab:**
- 🛡️ **95% ad blocking** via Pi-hole
- ⚡ **40-75% bandwidth savings** via Squid
- 🔐 **Secure remote access** via Wireguard
- 📊 **Real-time monitoring** via Netdata
- 🌐 **Professional networking** setup

**Performance Gains:**
- **DNS queries**: <1ms via local Pi-hole
- **Cached content**: 65%+ cache hit rate
- **VPN connection**: <5 second setup
- **Network latency**: <1ms internal routing

---

**📖 Full Setup Guide**: [GL.iNet X3000 Configuration Guide](gl-inet-x3000-setup.md)

**🎉 Quick setup complete! Your X3000 is optimized for the ZimaBoard 2 homelab.**
