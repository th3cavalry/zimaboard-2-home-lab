# File Share Data Directory

This directory is the mount point for the Samba network file share.

## Setup Instructions

You should mount your 2TB SSD to a parent directory and then bind-mount or symlink to this location. For example:

1. Mount your 2TB SSD to `/mnt/ssd`
2. Create a directory: `sudo mkdir -p /mnt/ssd/fileshare`
3. Update your docker-compose.yml to point to `/mnt/ssd/fileshare` instead of `./data/fileshare`

Or alternatively:
1. Mount your 2TB SSD directly to this location
2. Update the volume path in your docker-compose.yml accordingly

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
