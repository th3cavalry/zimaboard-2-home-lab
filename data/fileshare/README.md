# File Share Data Directory

This directory is the mount point for the Samba network file share.

## Setup Instructions

The docker-compose.yml is configured to use `/mnt/ssd/fileshare` as the Samba share location.

**Recommended Setup:**

1. Mount your 2TB SSD to `/mnt/ssd`
2. Create the fileshare directory: `sudo mkdir -p /mnt/ssd/fileshare`
3. The docker-compose.yml will automatically map this to the Samba container

The volume mapping in docker-compose.yml:
```yaml
${DATA_PATH_SSD:-/mnt/ssd}/fileshare:/shares/Shared
```

This means:
- **Host path**: `/mnt/ssd/fileshare` (or `${DATA_PATH_SSD}/fileshare` if you set a custom path)
- **Container path**: `/shares/Shared`

**Note**: This `./data/fileshare` directory in the repository is only a placeholder for reference. The actual Samba data should be stored on your SSD at `/mnt/ssd/fileshare`.

## Permissions
Ensure proper permissions are set on the mounted directory:
```bash
sudo chown -R nobody:nogroup /mnt/ssd/fileshare
sudo chmod -R 777 /mnt/ssd/fileshare
```

## Accessing the Share
Once configured:
- **Windows**: `\\YOUR-SERVER-IP\Shared`
- **macOS**: `smb://YOUR-SERVER-IP/Shared`
- **Linux**: `smb://YOUR-SERVER-IP/Shared` or mount via fstab
