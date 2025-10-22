# Helper Scripts

This directory contains helper scripts to assist with setup, validation, and maintenance of your ZimaBoard homelab.

## Available Scripts

### 1. validate-env.sh
**Purpose**: Validates your environment configuration before deployment

**Usage**:
```bash
bash scripts/validate-env.sh
```

**What it checks**:
- `.env` file exists and contains required variables
- Storage paths are accessible and writable
- Docker is installed and running
- Required ports are available
- Permissions are correctly set

**When to use**: Before deploying services for the first time, or after making changes to `.env`

---

### 2. setup-storage.sh
**Purpose**: Automates the detection, formatting, and mounting of storage drives

**Usage**:
```bash
sudo bash scripts/setup-storage.sh
```

**What it does**:
- Detects available storage drives (SSD and HDD)
- Formats drives with ext4 filesystem
- Creates mount points at `/mnt/ssd` and `/mnt/hdd`
- Adds entries to `/etc/fstab` for automatic mounting
- Creates service directories (fileshare, lancache, etc.)
- Optionally moves Docker data to SSD

**When to use**: During initial setup, before deploying services

**⚠️ WARNING**: This script formats drives and erases all data. Use with caution!

---

### 3. fix-permissions.sh
**Purpose**: Fixes permissions on storage directories that are not writable by the current user

**Usage**:
```bash
sudo bash scripts/fix-permissions.sh
```

**What it does**:
- Loads environment variables from `.env`
- Sets ownership of SSD and HDD mount points to the current user
- Sets proper permissions (777) on service directories:
  - `/mnt/ssd/fileshare` (for Samba)
  - `/mnt/hdd/lancache` (for Lancache cache)
  - `/mnt/hdd/lancache-logs` (for Lancache logs)
- Verifies directories are writable after fixing

**When to use**: 
- When `validate-env.sh` reports permission errors
- After manually mounting drives
- After system updates that may have reset permissions

**Example output**:
```
==================================
  Storage Permissions Fix Script
==================================

[INFO] Fixing permissions for user: yourusername
[OK] SSD path is now writable by yourusername
[OK] HDD path is now writable by yourusername
```

---

### 4. health-check.sh
**Purpose**: Verifies that all deployed services are running correctly

**Usage**:
```bash
bash scripts/health-check.sh
```

**What it checks**:
- Docker daemon is running
- All Docker Compose services are running
- Service ports are accessible
- DNS resolution is working
- Lancache is responding
- Samba shares are accessible
- Storage mounts are correct
- Disk space usage

**When to use**: After deployment, or when troubleshooting issues

---

### 5. reset-and-redeploy.sh
**Purpose**: Complete reset and redeploy with the latest version from GitHub

**Usage**:
```bash
sudo bash scripts/reset-and-redeploy.sh
```

**What it does**:
- Stops all running Docker services
- Removes all containers and volumes
- Cleans up old configurations (configs and data directories)
- Pulls latest code from GitHub (resets to origin/main)
- Backs up your .env file (preserves your settings)
- Downloads latest Docker images
- Recreates required directories
- Redeploys all services with fresh configuration

**What it PRESERVES**:
- ✓ Your .env file (backed up with timestamp)
- ✓ /mnt/ssd/fileshare (Samba file shares)
- ✓ /mnt/hdd/lancache (Lancache cache data)
- ✓ /mnt/hdd/lancache-logs (Lancache logs)

**What it DELETES**:
- ✗ All running containers
- ✗ All Docker volumes
- ✗ AdGuard Home configuration in ./data/adguardhome
- ✗ AdGuard Home settings in ./configs/adguardhome
- ✗ All other data in ./data and ./configs directories

**When to use**: 
- When you want to update to the latest repository version
- When you need to start fresh due to configuration issues
- When major updates have been made to the repository

**⚠️ WARNING**: This script will delete all AdGuard Home settings, configurations, and container data. Make sure you have backups if needed! You will need to reconfigure AdGuard Home after running this script.

---

## Typical Workflow

### Initial Setup
1. **Setup Storage**: `sudo bash scripts/setup-storage.sh`
2. **Configure Environment**: `cp .env.example .env && nano .env`
3. **Validate Configuration**: `bash scripts/validate-env.sh`
4. **Fix Permissions** (if needed): `sudo bash scripts/fix-permissions.sh`
5. **Deploy Services**: `docker compose up -d`
6. **Verify Deployment**: `bash scripts/health-check.sh`

### Regular Maintenance
- Run `bash scripts/health-check.sh` periodically to verify all services are healthy
- Run `bash scripts/validate-env.sh` after making changes to `.env`

### Updating to Latest Version
- Run `sudo bash scripts/reset-and-redeploy.sh` to update to the latest repository version
- This will pull latest code, update Docker images, and redeploy all services
- Your .env file will be backed up and preserved

### Troubleshooting
- If you encounter permission errors, run `sudo bash scripts/fix-permissions.sh`
- If services aren't working, run `bash scripts/health-check.sh` to identify issues
- Check Docker logs: `docker compose logs -f`
- Restart services: `docker compose restart`
- For a complete fresh start: `sudo bash scripts/reset-and-redeploy.sh`

---

## Notes

- All scripts are designed to be safe and provide clear output
- Scripts will ask for confirmation before making destructive changes
- Scripts use color-coded output for easy reading:
  - 🟢 Green: Success/Pass
  - 🟡 Yellow: Warning
  - 🔴 Red: Error/Fail
  - 🔵 Blue: Information

## Contributing

If you have ideas for additional helper scripts, please open an issue or pull request!
