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

### 3. health-check.sh
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

## Typical Workflow

### Initial Setup
1. **Setup Storage**: `sudo bash scripts/setup-storage.sh`
2. **Configure Environment**: `cp .env.example .env && nano .env`
3. **Validate Configuration**: `bash scripts/validate-env.sh`
4. **Deploy Services**: `docker compose up -d`
5. **Verify Deployment**: `bash scripts/health-check.sh`

### Regular Maintenance
- Run `bash scripts/health-check.sh` periodically to verify all services are healthy
- Run `bash scripts/validate-env.sh` after making changes to `.env`

### Troubleshooting
- If services aren't working, run `bash scripts/health-check.sh` to identify issues
- Check Docker logs: `docker compose logs -f`
- Restart services: `docker compose restart`

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
