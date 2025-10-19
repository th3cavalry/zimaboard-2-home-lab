#!/bin/bash

# ZimaBoard 2 Homelab Backup Script
# Backs up all configuration and data

set -e

# Configuration
BACKUP_DIR="/home/th3cavalry/homelab-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="zimaboard-homelab-backup-$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting homelab backup to $FULL_BACKUP_PATH"

# Create backup directory structure
mkdir -p "$FULL_BACKUP_PATH"/{config,data,logs,scripts,docker}

# Stop services for consistent backup
log "Stopping services for backup..."
docker-compose down

# Backup configurations
log "Backing up configurations..."
cp -r config/ "$FULL_BACKUP_PATH/"

# Backup data (excluding large temporary files)
log "Backing up data..."
rsync -av --exclude='*.tmp' --exclude='*.log' data/ "$FULL_BACKUP_PATH/data/"

# Backup logs (last 7 days only)
log "Backing up recent logs..."
find logs/ -name "*.log" -mtime -7 -exec cp {} "$FULL_BACKUP_PATH/logs/" \;

# Backup scripts
log "Backing up scripts..."
cp -r scripts/ "$FULL_BACKUP_PATH/"

# Backup Docker compose file
log "Backing up Docker configuration..."
cp docker-compose.yml "$FULL_BACKUP_PATH/"
cp .env "$FULL_BACKUP_PATH/" 2>/dev/null || true

# Export Docker images (optional, comment out if not needed)
log "Exporting Docker images..."
docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>") | gzip > "$FULL_BACKUP_PATH/docker/images.tar.gz"

# Create system info snapshot
log "Creating system information snapshot..."
cat > "$FULL_BACKUP_PATH/system-info.txt" << EOL
Backup Date: $(date)
Hostname: $(hostname)
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Memory: $(free -h | head -2 | tail -1)
Disk Usage: $(df -h /)
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version)

Running Containers:
$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}")

Network Configuration:
$(ip addr show)
EOL

# Create manifest
log "Creating backup manifest..."
find "$FULL_BACKUP_PATH" -type f -exec md5sum {} \; > "$FULL_BACKUP_PATH/manifest.md5"

# Compress backup
log "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Restart services
log "Restarting services..."
cd /home/th3cavalry/zimaboard-2-home-lab
docker-compose up -d

# Cleanup old backups (keep last 7 days)
log "Cleaning up old backups..."
find "$BACKUP_DIR" -name "zimaboard-homelab-backup-*.tar.gz" -mtime +7 -delete

# Calculate backup size
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)

log "Backup completed successfully!"
log "Backup file: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
log "Backup size: $BACKUP_SIZE"

# Optional: Send backup to remote location
# Uncomment and configure the following lines for remote backup
# log "Uploading backup to remote location..."
# rsync -av "$BACKUP_DIR/$BACKUP_NAME.tar.gz" user@remote-server:/backup/zimaboard/
# log "Remote backup uploaded successfully."

log "Backup process completed."
