#!/bin/bash
################################################################################
# ZimaBoard Homelab - Complete Reset and Redeploy Script
# 
# This script will:
# 1. Stop all running services
# 2. Remove all containers and volumes
# 3. Clean up old configurations
# 4. Pull latest code from GitHub
# 5. Download latest images
# 6. Redeploy everything fresh
#
# WARNING: This will DELETE all AdGuard Home settings, Lancache data, etc.
# Make sure you have backups if needed!
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as correct user
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
    exit 1
fi

# Get the actual user who ran sudo
ACTUAL_USER="${SUDO_USER:-$USER}"
HOME_DIR=$(eval echo ~"$ACTUAL_USER")

################################################################################
# STEP 1: Display Warning and Get Confirmation
################################################################################

clear
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         ⚠️  COMPLETE RESET AND REDEPLOY WARNING ⚠️           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  This script will DELETE:                                   ║"
echo "║  ✗ All running containers                                   ║"
echo "║  ✗ All container volumes                                    ║"
echo "║  ✗ Old AdGuard Home configuration and settings              ║"
echo "║  ✗ Old Lancache data and cache logs                         ║"
echo "║  ✗ All local configuration in ./configs and ./data          ║"
echo "║                                                              ║"
echo "║  Files that will be PRESERVED:                              ║"
echo "║  ✓ /mnt/ssd/fileshare (Samba shares)                        ║"
echo "║  ✓ /mnt/hdd/lancache (Lancache cache)                       ║"
echo "║  ✓ Your .env file (backed up)                               ║"
echo "║  ✓ Repository code (will be updated)                        ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

read -p "Do you want to continue? Type 'YES' to proceed: " -r
echo
if [[ ! $REPLY =~ ^YES$ ]]; then
    error "Operation cancelled"
    exit 1
fi

################################################################################
# STEP 2: Change to Repository Directory
################################################################################

log "Changing to homelab repository..."
cd "$HOME_DIR/zimaboard-2-home-lab" || {
    error "Repository not found at $HOME_DIR/zimaboard-2-home-lab"
    exit 1
}
success "Working directory: $(pwd)"

################################################################################
# STEP 3: Backup Current .env File
################################################################################

log "Backing up current .env file..."
if [[ -f .env ]]; then
    BACKUP_FILE=".env.backup.$(date +%Y%m%d_%H%M%S)"
    cp .env "$BACKUP_FILE"
    success "Backed up to: $BACKUP_FILE"
else
    warning "No .env file found (will need to create one)"
fi

################################################################################
# STEP 4: Stop All Running Services
################################################################################

log "Stopping all Docker services..."
if docker compose ps | grep -q "running"; then
    docker compose down --remove-orphans || true
    sleep 2
    success "Services stopped"
else
    log "No running services found"
fi

################################################################################
# STEP 5: Remove Docker Resources
################################################################################

log "Removing Docker containers, volumes, and images..."
warning "This may take a minute..."

# Remove all stopped containers
docker container prune -f --filter "label!=keep" || true

# Remove homelab-specific volumes
docker volume ls | grep homelab | awk '{print $2}' | xargs -r docker volume rm || true

# Remove unused networks
docker network prune -f || true

# Remove dangling images
docker image prune -f || true

success "Docker resources cleaned"

################################################################################
# STEP 6: Remove Local Configuration and Data Directories
################################################################################

log "Cleaning up local configuration directories..."

# Remove old configs (will be refreshed from repo)
rm -rf ./configs/adguardhome/* 2>/dev/null || true
rm -rf ./configs/lancache/* 2>/dev/null || true
rm -rf ./configs/samba/* 2>/dev/null || true

# Remove old data directories (will be recreated)
rm -rf ./data/adguardhome/* 2>/dev/null || true
rm -rf ./data/uptime-kuma/* 2>/dev/null || true
rm -rf ./data/crowdsec/* 2>/dev/null || true

success "Old configurations and data cleaned"

################################################################################
# STEP 7: Update Repository from GitHub
################################################################################

log "Updating repository from GitHub..."

# Fetch latest changes
git fetch origin main || {
    error "Failed to fetch from GitHub. Check your internet connection."
    exit 1
}

# Reset to latest main branch
git reset --hard origin/main || {
    error "Failed to reset repository to latest version"
    exit 1
}

# Clean any untracked files
git clean -fd || true

success "Repository updated to latest version"

################################################################################
# STEP 8: Verify Essential Files Exist
################################################################################

log "Verifying essential files..."

FILES_TO_CHECK=(
    "docker-compose.yml"
    ".env.example"
    "configs/adguardhome/AdGuardHome.yaml"
    "configs/samba/smb.conf"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [[ -f "$file" ]]; then
        success "✓ $file"
    else
        error "✗ $file MISSING!"
        exit 1
    fi
done

################################################################################
# STEP 9: Restore or Create .env File
################################################################################

log "Configuring environment file..."

if [[ -f "$BACKUP_FILE" ]]; then
    log "Restoring from backup: $BACKUP_FILE"
    cp "$BACKUP_FILE" .env
    success ".env restored"
else
    log "Creating new .env file from template..."
    cp .env.example .env
    warning "Please edit .env with your configuration:"
    warning "  nano .env"
    warning "Then run this script again, or manually start services with:"
    warning "  docker compose up -d"
    exit 0
fi

################################################################################
# STEP 10: Create Required Directories
################################################################################

log "Creating required directories..."

# Create directories for data volumes
mkdir -p ./data/adguardhome
mkdir -p ./data/uptime-kuma
mkdir -p ./data/crowdsec/config
mkdir -p ./data/crowdsec/data
mkdir -p ./data/fileshare

# Verify external mount points exist
if [[ ! -d /mnt/ssd ]]; then
    warning "/mnt/ssd not found - you may need to mount your SSD"
else
    mkdir -p /mnt/ssd/fileshare
    chmod 777 /mnt/ssd/fileshare
fi

if [[ ! -d /mnt/hdd ]]; then
    warning "/mnt/hdd not found - you may need to mount your HDD"
else
    mkdir -p /mnt/hdd/lancache
    mkdir -p /mnt/hdd/lancache-logs
    chmod 777 /mnt/hdd/lancache
    chmod 777 /mnt/hdd/lancache-logs
fi

success "Directories created"

################################################################################
# STEP 11: Pull Latest Docker Images
################################################################################

log "Pulling latest Docker images..."
warning "This may take several minutes depending on your internet speed..."

docker compose pull || {
    error "Failed to pull Docker images"
    exit 1
}

success "Docker images updated"

################################################################################
# STEP 12: Verify .env Configuration
################################################################################

log "Verifying .env configuration..."

# Source the .env file
set -a
source .env 2>/dev/null || true
set +a

# Check critical variables
if [[ -z "${SERVER_IP:-}" ]]; then
    error ".env missing SERVER_IP"
    exit 1
fi

if [[ -z "${TIMEZONE:-}" ]]; then
    error ".env missing TIMEZONE"
    exit 1
fi

success "Configuration verified:"
success "  SERVER_IP: $SERVER_IP"
success "  TIMEZONE: $TIMEZONE"
success "  DATA_PATH_SSD: ${DATA_PATH_SSD:-/mnt/ssd}"
success "  DATA_PATH_HDD: ${DATA_PATH_HDD:-/mnt/hdd}"

################################################################################
# STEP 13: Start Services
################################################################################

log "Starting Docker services..."
log "This may take 30-60 seconds for all services to become healthy..."

docker compose up -d || {
    error "Failed to start services"
    docker compose logs
    exit 1
}

# Wait for services to stabilize
sleep 5

################################################################################
# STEP 14: Verify Services Are Running
################################################################################

log "Verifying services are running..."

SERVICES=("adguardhome" "lancache" "samba")

for service in "${SERVICES[@]}"; do
    if docker compose ps | grep -q "$service"; then
        success "✓ $service running"
    else
        error "✗ $service NOT running"
    fi
done

################################################################################
# STEP 15: Display Service Status
################################################################################

log "Complete service status:"
echo
docker compose ps
echo

################################################################################
# STEP 16: Display Access Information
################################################################################

log "Services are now running!"
echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 HOMELAB RESET AND REDEPLOY COMPLETE! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo

echo "📍 Service Addresses:"
echo "   AdGuard Home:  http://$SERVER_IP:3000"
printf "   Samba Share:   \\\\\\\\%s\\\\Shared\n" "$SERVER_IP"
echo "   Lancache:      (Transparent - via DNS rewrites)"
echo

echo "🔧 Next Steps:"
echo "   1. Access AdGuard Home: http://$SERVER_IP:3000"
echo "   2. Complete the initial setup wizard"
echo "   3. Verify DNS rewrites are configured (Filters → DNS rewrites)"
echo "   4. Configure your router DNS to point to: $SERVER_IP"
echo "   5. Test with: nslookup steamcontent.com $SERVER_IP"
echo

echo "📊 View Logs:"
echo "   docker compose logs -f adguardhome"
echo "   docker compose logs -f lancache"
echo "   docker compose logs -f samba"
echo

echo "💾 Backups:"
if [[ -f "$BACKUP_FILE" ]]; then
    echo "   Your previous .env backed up to: $BACKUP_FILE"
fi
echo

success "Setup complete! $(date '+%Y-%m-%d %H:%M:%S')"

exit 0
