# GL.iNet X3000 Setup Guide for ZimaBoard 2 Homelab

## 📱 Step 1: Access X3000 Admin Interface

1. **Connect to X3000 WiFi**:
   - SSID: `GL-X3000-XXX` (check device label)
   - Password: `goodlife` (default)

2. **Open web browser** and go to: `192.168.8.1`
   - Default login: `admin` / `admin`

## 🌐 Step 2: Configure Internet Connection

### **Cellular Setup:**
1. Go to **Internet** → **Cellular**
2. Insert your SIM card
3. Configure APN settings for your carrier:
   - **Verizon**: `vzwinternet`
   - **AT&T**: `broadband` or `phone`
   - **T-Mobile**: `fast.t-mobile.com`
4. Click **Apply** and wait for connection

### **Verify Internet:**
- Check status shows "Connected"
- Test internet access from X3000

## 🏠 Step 3: Network Configuration for ZimaBoard

### **LAN Settings:**
1. Go to **Network** → **LAN**
2. Set **LAN IP**: `192.168.8.1` (keep default)
3. Set **Subnet Mask**: `255.255.255.0`
4. **DHCP Range**: `192.168.8.100` - `192.168.8.200`

### **Reserve IP for ZimaBoard:**
1. Go to **Network** → **DHCP Reservations**
2. Add reservation:
   - **MAC Address**: (ZimaBoard MAC - check with `ip link`)
   - **IP Address**: `192.168.8.2`
   - **Hostname**: `zimaboard`

## 🛡️ Step 4: DNS Configuration (Pi-hole Integration)

### **Set ZimaBoard as DNS Server:**
1. Go to **Network** → **DNS**
2. Set **Primary DNS**: `192.168.8.100` (ZimaBoard Pi-hole)
3. Set **Secondary DNS**: `1.1.1.1` (backup)
4. **Enable DNS Rebinding Protection**: OFF
5. Click **Apply**

### **DHCP DNS Settings:**
1. Go to **Network** → **DHCP Server**
2. Set **Primary DNS**: `192.168.8.100`
3. Set **Secondary DNS**: `1.1.1.1`
4. This makes all devices use Pi-hole automatically

## 🔧 Step 5: Advanced Configuration

### **Port Forwarding (Optional):**
If you need external access to services:
1. Go to **Network** → **Port Forwards**
2. Add rules:
   - **Proxmox**: External `8006` → `192.168.8.2:8006`
   - **Pi-hole**: External `8080` → `192.168.8.100:80`
   - **Seafile**: External `8000` → `192.168.8.101:8000`

### **DMZ Configuration (Alternative):**
For simple external access:
1. Go to **Network** → **DMZ**
2. Set **DMZ Host**: `192.168.8.2` (ZimaBoard)
3. **⚠️ Warning**: This exposes ZimaBoard to internet

### **Firewall Rules:**
1. Go to **Network** → **Firewall**
2. **Allow LAN to WAN**: Enabled
3. **Block WAN to LAN**: Enabled (except port forwards)
4. **SPI Firewall**: Enabled

## 📊 Step 6: Quality of Service (QoS)

### **Bandwidth Management:**
1. Go to **Network** → **QoS**
2. **Enable Smart QoS**
3. Set bandwidth limits:
   - **Download**: 80% of your cellular plan speed
   - **Upload**: 80% of your cellular plan speed
4. **Gaming Mode**: Enable for low latency

### **Device Prioritization:**
1. Set **ZimaBoard** (`192.168.8.2`) to **High Priority**
2. Set other devices to **Normal** or **Low**

## 🔄 Step 7: Cellular Optimization

### **Data Usage Monitoring:**
1. Go to **Internet** → **Cellular** → **Data Usage**
2. Set **Monthly Limit** based on your plan
3. Enable **Usage Alerts** at 80% and 95%

### **Connection Optimization:**
1. **Band Selection**: Auto (or lock to best local bands)
2. **Network Mode**: 5G/4G Auto
3. **Connection Mode**: Auto-connect
4. **Roaming**: Disable (unless needed)

### **Antenna Optimization:**
1. Use **Signal Strength** meter in admin interface
2. Position antennas for best signal
3. **MIMO**: Enable if available
4. **Carrier Aggregation**: Enable for faster speeds

## 🔗 Step 8: ZimaBoard Integration

### **Configure ZimaBoard Static IP:**
SSH into ZimaBoard and run:
```bash
# Set static IP on ZimaBoard
nmcli con mod "Wired connection 1" ipv4.addresses "192.168.8.2/24"
nmcli con mod "Wired connection 1" ipv4.gateway "192.168.8.1"
nmcli con mod "Wired connection 1" ipv4.dns "127.0.0.1"
nmcli con mod "Wired connection 1" ipv4.method manual
nmcli con up "Wired connection 1"

# Verify configuration
ip addr show
ping 192.168.8.1  # Test gateway
ping 8.8.8.8      # Test internet
```

### **Test Pi-hole DNS:**
```bash
# Test DNS resolution through Pi-hole
nslookup doubleclick.net 192.168.8.2  # Should be blocked
nslookup google.com 192.168.8.2       # Should resolve
```

## 📱 Step 9: WiFi Configuration

### **Primary WiFi Network:**
1. Go to **Wireless** → **WiFi Settings**
2. **SSID**: `HomeNet-Secure`
3. **Security**: WPA3-SAE (or WPA2-PSK if devices don't support WPA3)
4. **Password**: Strong password (20+ characters)
5. **Band**: 5GHz for high speed, 2.4GHz for range

### **Guest Network:**
1. Enable **Guest Network**
2. **SSID**: `HomeNet-Guest`
3. **Bandwidth Limit**: 50% of main network
4. **Time Restrictions**: Optional

## 🔐 Step 10: Security Hardening

### **Admin Security:**
1. **Change admin password** to strong password
2. **Enable 2FA** if available
3. **Set session timeout**: 30 minutes
4. **Disable WPS**: For security

### **Remote Management:**
1. **Disable remote management** unless needed
2. If enabled, use **VPN access only**
3. **Change default ports** for security

### **Firmware Updates:**
1. Go to **System** → **Upgrade**
2. **Enable auto-updates** for security patches
3. **Check for updates** monthly

## 📊 Step 11: Monitoring and Maintenance

### **Performance Monitoring:**
1. **Signal Strength**: Check regularly in admin interface
2. **Data Usage**: Monitor monthly consumption
3. **Temperature**: Ensure device doesn't overheat
4. **Connection Stability**: Check for frequent disconnects

### **Regular Maintenance:**
- **Reboot monthly**: For optimal performance
- **Clear logs**: Monthly to free space
- **Update firmware**: When available
- **Check antennas**: Ensure secure connections

## 🎯 Step 12: Integration Testing

### **Test Complete Setup:**
```bash
# From any device on network, test:
curl -I http://192.168.8.2:8080/admin     # Pi-hole admin
curl -I http://192.168.8.2:8000           # Seafile
curl -I http://192.168.8.2                # Nginx dashboard
ping 192.168.8.2                          # ZimaBoard connectivity

# Test DNS filtering:
nslookup ads.google.com    # Should be blocked by Pi-hole
nslookup google.com        # Should resolve normally
```

### **Speed Test:**
1. **Baseline**: Test speed directly on X3000
2. **With Pi-hole**: Test speed through ZimaBoard
3. **With Squid**: Test cached content performance
4. **Compare**: Ensure minimal performance impact

## ✅ Final Configuration Summary

**Network Layout:**
```
Internet (Cellular) 
    ↓
GL.iNet X3000 (192.168.8.1)
    ↓
ZimaBoard 2 (192.168.8.2)
    ↓
Homelab Services:
- Pi-hole DNS (Port 53)
- Squid Proxy (Port 3128)
- Wireguard VPN (Port 51820)
- Web Services (Ports 80, 8000, 8080)
```

**Key Benefits:**
- **95% ad blocking** network-wide
- **40-75% bandwidth savings** with caching
- **Secure VPN access** when away from home
- **Real-time monitoring** of all network traffic
- **Professional-grade security** with cellular internet

## 🔧 Troubleshooting

### **No Internet on ZimaBoard:**
1. Check Ethernet cable connection
2. Verify X3000 has cellular connection
3. Check IP configuration on ZimaBoard
4. Test ping to gateway: `ping 192.168.8.1`

### **DNS Not Working:**
1. Check Pi-hole is running: `pct status 100`
2. Verify DNS settings on X3000
3. Test direct DNS: `nslookup google.com 192.168.8.2`

### **Slow Performance:**
1. Check cellular signal strength
2. Verify QoS settings
3. Check data usage limits
4. Test with/without Squid proxy

### **Can't Access Services:**
1. Verify ZimaBoard services are running
2. Check firewall rules
3. Test local access first
4. Verify port forwarding if accessing externally

**🎉 Your GL.iNet X3000 is now optimally configured for the ZimaBoard 2 homelab!**
