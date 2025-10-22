# AdGuard Home Configuration

This directory contains the configuration files for AdGuard Home.

When you first start AdGuard Home, it will generate its configuration files here automatically during the initial setup wizard.

## Initial Setup - Important Binding Configuration

When you run the initial setup wizard at `http://192.168.8.2:3000`, you'll be prompted to configure interface bindings. **This is critical for proper access.**

### Recommended Settings:

- **Admin Web Interface**:
  - Listen Interface: `All interfaces (0.0.0.0)`
  - Port: `3000`

- **DNS Server**:
  - Listen Interface: `All interfaces (0.0.0.0)`  
  - Port: `53`

**Why 0.0.0.0?**
- Allows access from any network interface
- Works with both Docker and bare-metal installations
- Ensures the service is reachable from your network

**Common Mistake:** Setting the binding to `127.0.0.1` or leaving it at a specific container IP will make AdGuard Home unreachable from your network.

## Files Generated
- `AdGuardHome.yaml` - Main configuration file
- Other runtime files as needed

## Manual Configuration
You can manually edit `AdGuardHome.yaml` after the initial setup, but it's recommended to use the web interface at `http://YOUR-SERVER-IP:3000` for most configuration changes.

### Example binding configuration in AdGuardHome.yaml:
```yaml
bind_host: 0.0.0.0
bind_port: 3000
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
```

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
