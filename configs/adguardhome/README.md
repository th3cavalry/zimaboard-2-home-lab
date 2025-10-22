# AdGuard Home Configuration

This directory contains the configuration files for AdGuard Home.

## Pre-Configured Setup (Recommended)

**✅ SOLUTION TO THE 0.0.0.0 BINDING ISSUE**

This repository includes a **pre-configured `AdGuardHome.yaml`** file that solves the common problem where the web interface setup wizard doesn't allow selecting `0.0.0.0` (all interfaces) for binding.

### What's Included

The pre-configured file (`AdGuardHome.yaml`) already has:
- ✅ **Admin Web Interface**: Bound to `0.0.0.0:3000` (all interfaces)
- ✅ **DNS Server**: Bound to `0.0.0.0:53` (all interfaces)
- ✅ **Default Upstream DNS**: Cloudflare (1.1.1.1, 1.0.0.1) and Google (8.8.8.8, 8.8.4.4)
- ✅ **Basic Ad Blocking Filters**: AdGuard DNS filter and AdAway Default Blocklist
- ✅ **Sensible Defaults**: Cache size, rate limiting, and security settings

### How to Use

1. **Start AdGuard Home** (the config file is already in place):
   ```bash
   # For Path A (Docker):
   docker compose up -d
   
   # For Path B (Bare-metal):
   sudo systemctl start AdGuardHome
   ```

2. **Access the Web Interface**:
   - Open your browser to: `http://YOUR-SERVER-IP:3000`
   - Replace `YOUR-SERVER-IP` with your actual IP (e.g., `192.168.8.2`)

3. **Complete Initial Setup**:
   - Create your admin username and password
   - The interface and DNS bindings are **already configured** to `0.0.0.0`
   - Click through the wizard to complete setup

4. **Verify It's Working**:
   - You should be able to access AdGuard Home from any device on your network
   - The dashboard should show incoming DNS queries

### Why This Solves the Problem

The AdGuard Home web interface setup wizard has a limitation: it only displays specific network interfaces (like `127.0.0.1`, `172.20.0.2`, `::1`) and doesn't provide an option to manually enter `0.0.0.0`. 

By providing a pre-configured `AdGuardHome.yaml` file with `bind_host: 0.0.0.0`, users can:
- **Skip the problematic interface selection** step
- **Ensure proper binding** to all network interfaces
- **Access AdGuard Home** from any device on the network immediately

### Why 0.0.0.0?

Binding to `0.0.0.0` means "listen on all network interfaces":
- ✅ Accessible from the local machine (`127.0.0.1`)
- ✅ Accessible from the Docker network (`172.20.0.x`)
- ✅ Accessible from your LAN (`192.168.x.x`)
- ✅ Works with both Docker and bare-metal installations
- ✅ Maximum flexibility for network access

## Files Generated
- `AdGuardHome.yaml` - Main configuration file (pre-configured in this repository)
- Query logs and statistics (in the `data/adguardhome/` directory)

## Manual Configuration (If Needed)

If you need to manually change the binding address later:

1. **Stop AdGuard Home**:
   ```bash
   # For Path A (Docker):
   docker compose stop adguard
   
   # For Path B (Bare-metal):
   sudo systemctl stop AdGuardHome
   ```

2. **Edit the configuration**:
   ```bash
   nano AdGuardHome.yaml
   ```

3. **Find and update these settings**:
   ```yaml
   bind_host: 0.0.0.0
   bind_port: 3000
   dns:
     bind_hosts:
       - 0.0.0.0
     port: 53
   ```

4. **Restart AdGuard Home**:
   ```bash
   # For Path A (Docker):
   docker compose up -d
   
   # For Path B (Bare-metal):
   sudo systemctl start AdGuardHome
   ```

## Alternative: Starting Fresh Without Pre-Config

If you want to start completely fresh and go through the web wizard (not recommended due to the binding issue):

1. **Backup or rename** the existing config:
   ```bash
   mv AdGuardHome.yaml AdGuardHome.yaml.backup
   ```

2. **Start AdGuard Home** - it will create a new default config

3. **During setup wizard**, you'll face the limitation of not being able to select `0.0.0.0`
   - As a workaround, select your server's specific IP (e.g., `192.168.8.2`)
   - After setup completes, manually edit the config file to change to `0.0.0.0`

**Note**: It's much easier to use the pre-configured file provided in this repository!

## Troubleshooting

If you cannot access AdGuard Home after setup:

1. Check the configuration file:
   ```bash
   cat AdGuardHome.yaml | grep bind
   ```

2. Verify `bind_host` is set to `0.0.0.0`

3. If not, edit the file and restart AdGuard Home:
   - **Docker**: `docker compose restart adguard`
   - **Bare-metal**: `sudo systemctl restart AdGuardHome`
