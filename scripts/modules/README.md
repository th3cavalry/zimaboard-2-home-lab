# Installation Modules

This directory contains modular installation scripts for the ZimaBoard 2 homelab.

## Module Order

The modules are executed in this order:

1. **00-system-prep.sh** - System updates and basic setup
2. **01-storage-setup.sh** - Interactive SSD configuration
3. **02-adguard.sh** - AdGuard Home DNS server
4. **03-nginx.sh** - Web server and reverse proxy
5. **04-nextcloud.sh** - Personal cloud and office suite
6. **05-wireguard.sh** - VPN server configuration
7. **06-squid.sh** - Bandwidth optimization proxy
8. **07-netdata.sh** - System monitoring
9. **08-security.sh** - Firewall and security hardening
10. **99-finalize.sh** - Final configuration and verification

## Module Structure

Each module should:

- Be self-contained and idempotent
- Include proper error handling
- Provide clear status output
- Support dry-run mode (future enhancement)
- Log operations for debugging

## Shared Functions

Common functions are available from `../utils/common.sh`:

- `print_info()` - Blue informational messages
- `print_success()` - Green success messages  
- `print_warning()` - Yellow warning messages
- `print_error()` - Red error messages
- `check_root()` - Verify root privileges
- `check_ubuntu()` - Verify Ubuntu system

## Usage

Modules can be run individually for testing:

```bash
sudo ./scripts/modules/02-adguard.sh
```

Or all together via the main installer:

```bash
sudo ./install.sh
```
