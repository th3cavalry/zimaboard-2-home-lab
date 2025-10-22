# AdGuard Home Binding Configuration for Bare-Metal Installation

## The Problem

When running AdGuard Home in bare-metal mode (Path B), the initial setup wizard doesn't allow manually entering `0.0.0.0` for binding. It only shows specific interface IPs like:
- `127.0.0.1` (localhost)
- Your server's IP (e.g., `192.168.8.2`)
- `::1` (IPv6 localhost)

This can cause accessibility issues if you select the wrong interface.

## The Solution

After running the bare-metal installation script, you need to manually configure AdGuard Home to bind to `0.0.0.0` (all interfaces).

### Method 1: Edit Config Before First Setup (Recommended)

**Before** running the AdGuard Home setup wizard for the first time:

1. Stop AdGuard Home:
   ```bash
   sudo systemctl stop AdGuardHome
   ```

2. Check if config exists:
   ```bash
   ls -la /opt/AdGuardHome/AdGuardHome.yaml
   ```

3. If the config doesn't exist yet, create it with the correct binding:
   ```bash
   sudo curl -o /opt/AdGuardHome/AdGuardHome.yaml \
     https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/configs/adguardhome/AdGuardHome.yaml
   ```

4. Start AdGuard Home:
   ```bash
   sudo systemctl start AdGuardHome
   ```

5. Access the web interface:
   ```
   http://YOUR-SERVER-IP:3000
   ```

6. Complete the setup wizard (the binding is already configured to `0.0.0.0`)

### Method 2: Edit Config After Setup

If you've already completed the setup wizard and can't access AdGuard Home from the network:

1. Stop AdGuard Home:
   ```bash
   sudo systemctl stop AdGuardHome
   ```

2. Edit the configuration:
   ```bash
   sudo nano /opt/AdGuardHome/AdGuardHome.yaml
   ```

3. Find and change the `bind_host` setting:
   ```yaml
   bind_host: 0.0.0.0  # Change from 127.0.0.1 or specific IP
   bind_port: 3000
   ```

4. Also update the DNS binding:
   ```yaml
   dns:
     bind_hosts:
       - 0.0.0.0  # Change from specific IP
     port: 53
   ```

5. Save the file (Ctrl+X, then Y, then Enter)

6. Start AdGuard Home:
   ```bash
   sudo systemctl start AdGuardHome
   ```

7. Verify it's listening on all interfaces:
   ```bash
   sudo ss -tulpn | grep :3000
   # Should show: 0.0.0.0:3000
   ```

## Why Bind to 0.0.0.0?

Binding to `0.0.0.0` means "listen on all network interfaces":
- ✅ Accessible from localhost (`127.0.0.1`)
- ✅ Accessible from your LAN (e.g., `192.168.8.2`)
- ✅ Accessible from any other network interfaces
- ✅ Maximum flexibility for different network configurations
- ✅ Ensures the service works correctly for all clients on your network

## Troubleshooting

### Can't Access AdGuard Home After Installation

1. Check if the service is running:
   ```bash
   sudo systemctl status AdGuardHome
   ```

2. Check what it's listening on:
   ```bash
   sudo ss -tulpn | grep :3000
   ```

3. If it shows `127.0.0.1:3000` instead of `0.0.0.0:3000`, follow Method 2 above

4. Check firewall:
   ```bash
   sudo ufw status
   # If active, allow the ports:
   sudo ufw allow 3000/tcp
   sudo ufw allow 53/tcp
   sudo ufw allow 53/udp
   ```

### Port Already in Use

If you get an error about port 53 being in use:

```bash
# Stop systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Update DNS resolution
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
sudo chattr +i /etc/resolv.conf

# Restart AdGuard Home
sudo systemctl restart AdGuardHome
```

## Additional Resources

For complete setup instructions, see the main README.md file, Section 4 (Path B - Bare-Metal/Hybrid Guide).
