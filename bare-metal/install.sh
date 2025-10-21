#!/bin/bash
################################################################################
# ZimaBoard Homelab - Bare-Metal Installation Script (Path B)
# 
# This script installs services directly on the host OS:
# - AdGuard Home (bare-metal)
# - Samba (bare-metal)
# 
# Complex services like Lancache remain containerized (see docker-compose.hybrid.yml)
#
# Hardware: ZimaBoard 2 (x86-64, 16GB RAM, 64GB eMMC, 2TB SSD, 500GB HDD)
# OS: Ubuntu Server 22.04 LTS
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Header
clear
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      ZimaBoard Homelab - Bare-Metal Installation (Path B)   ║"
echo "║                                                              ║"
echo "║  Installing: AdGuard Home + Samba (Direct on Host)          ║"
echo "║  Hybrid: Lancache via Docker (see docker-compose.hybrid.yml)║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Please use: sudo bash install.sh"
    exit 1
fi

# Get the user who invoked sudo
ACTUAL_USER="${SUDO_USER:-$USER}"
if [[ "$ACTUAL_USER" == "root" ]]; then
    warning "Running as root directly. Consider creating a regular user."
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check Ubuntu version
if ! grep -qE "Ubuntu (22.04|24.04)" /etc/os-release 2>/dev/null; then
    warning "This script is designed for Ubuntu Server 22.04 LTS"
    warning "Detected: $(lsb_release -d | cut -f2)"
    read -p "Continue anyway? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Display system information
SYSTEM_IP=$(hostname -I | awk '{print $1}' | head -1)
if [[ -z "$SYSTEM_IP" ]]; then
    SYSTEM_IP="localhost"
fi

log "System Information:"
info "  IP Address: $SYSTEM_IP"
info "  Hostname: $(hostname)"
info "  OS: $(lsb_release -d | cut -f2)"
echo

log "This script will install:"
echo "  🛡️  AdGuard Home (DNS filtering & ad blocking)"
echo "  📁  Samba (Network file storage)"
echo
warning "Note: Lancache and optional services (Uptime Kuma, CrowdSec) will be"
warning "      installed via Docker in the next step (docker-compose.hybrid.yml)"
echo

# Get confirmation
read -p "Continue with bare-metal installation? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Installation cancelled by user"
    exit 0
fi

################################################################################
# Phase 1: System Update
################################################################################

log "Phase 1: Updating system packages..."
apt update
apt upgrade -y
success "System packages updated"
echo

################################################################################
# Phase 2: Install AdGuard Home
################################################################################

log "Phase 2: Installing AdGuard Home..."

# Check if AdGuard Home is already installed
if command -v AdGuardHome &> /dev/null; then
    warning "AdGuard Home is already installed. Skipping installation."
else
    info "Downloading and installing AdGuard Home..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download and install AdGuard Home using official script
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    success "AdGuard Home installed successfully"
fi

# Enable and start AdGuard Home service
systemctl enable AdGuardHome
systemctl start AdGuardHome

# Check if service is running
if systemctl is-active --quiet AdGuardHome; then
    success "AdGuard Home service is running"
    info "Access AdGuard Home at: http://$SYSTEM_IP:3000"
else
    error "AdGuard Home service failed to start"
    error "Check logs with: sudo journalctl -u AdGuardHome -n 50"
fi

echo

################################################################################
# Phase 3: Install Samba
################################################################################

log "Phase 3: Installing Samba..."

# Install Samba
apt install -y samba samba-common-bin

success "Samba installed successfully"

# Backup existing smb.conf if it exists
if [[ -f /etc/samba/smb.conf ]]; then
    info "Backing up existing Samba configuration..."
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d-%H%M%S)
    success "Backup created: /etc/samba/smb.conf.backup.*"
fi

# Copy pre-configured smb.conf
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$REPO_ROOT/configs/samba/smb.conf" ]]; then
    info "Installing pre-configured Samba configuration..."
    cp "$REPO_ROOT/configs/samba/smb.conf" /etc/samba/smb.conf
    success "Samba configuration installed"
else
    warning "Pre-configured smb.conf not found at $REPO_ROOT/configs/samba/smb.conf"
    warning "Using default Samba configuration"
fi

# Ensure the share directory exists
info "Checking Samba share directory..."
if [[ ! -d /mnt/ssd/fileshare ]]; then
    warning "Share directory /mnt/ssd/fileshare does not exist"
    warning "Please create it with: sudo mkdir -p /mnt/ssd/fileshare && sudo chmod 777 /mnt/ssd/fileshare"
else
    info "Share directory exists: /mnt/ssd/fileshare"
    # Set proper permissions
    chmod 777 /mnt/ssd/fileshare
    success "Permissions set on share directory"
fi

# Restart Samba services
log "Starting Samba services..."
systemctl enable smbd nmbd
systemctl restart smbd nmbd

# Check if services are running
if systemctl is-active --quiet smbd && systemctl is-active --quiet nmbd; then
    success "Samba services are running"
else
    error "Samba services failed to start"
    error "Check logs with: sudo journalctl -u smbd -n 50"
    error "                 sudo journalctl -u nmbd -n 50"
fi

echo

################################################################################
# Phase 4: Configure Samba User (Optional)
################################################################################

log "Phase 4: Samba User Configuration"
info "The current Samba configuration allows guest access (no password required)"
echo

read -p "Do you want to create a Samba user for authenticated access? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter username for Samba access [$ACTUAL_USER]: " SAMBA_USER
    SAMBA_USER="${SAMBA_USER:-$ACTUAL_USER}"
    
    # Create system user if it doesn't exist
    if ! id "$SAMBA_USER" &>/dev/null; then
        info "Creating system user: $SAMBA_USER"
        useradd -m -s /bin/bash "$SAMBA_USER"
    fi
    
    # Set Samba password
    info "Setting Samba password for user: $SAMBA_USER"
    smbpasswd -a "$SAMBA_USER"
    smbpasswd -e "$SAMBA_USER"
    
    success "Samba user '$SAMBA_USER' configured"
    info "You can now access the share with username: $SAMBA_USER"
    echo
    
    warning "To enable authentication, edit /etc/samba/smb.conf and change:"
    warning "  guest ok = yes  -->  guest ok = no"
    warning "  valid users = $SAMBA_USER"
    warning "Then restart Samba: sudo systemctl restart smbd nmbd"
else
    info "Skipping Samba user creation. Guest access will be used."
fi

echo

################################################################################
# Phase 5: Display Next Steps
################################################################################

log "Bare-Metal Installation Complete!"
echo
success "✅ AdGuard Home is running at: http://$SYSTEM_IP:3000"
success "✅ Samba share is available at: \\\\$SYSTEM_IP\\Shared"
echo

warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
warning "NEXT STEPS - Complete Your Hybrid Setup:"
warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "1. Configure Docker services (Lancache + Optional services):"
echo "   cd $REPO_ROOT/bare-metal"
echo "   cp .env.hybrid.example .env.hybrid"
echo "   nano .env.hybrid  # Edit configuration (SERVER_IP, paths, etc.)"
echo

info "2. Start Docker hybrid services:"
echo "   docker compose -f docker-compose.hybrid.yml --env-file .env.hybrid up -d"
echo

info "3. Configure AdGuard Home:"
echo "   - Open http://$SYSTEM_IP:3000 in your browser"
echo "   - Complete the initial setup wizard"
echo "   - Add DNS blocklists (see README.md for recommendations)"
echo "   - Configure DNS rewrites for Lancache (see README.md)"
echo

info "4. Configure your router (GL.iNet x3000):"
echo "   - Set Primary DNS to: $SYSTEM_IP"
echo "   - This will route all network traffic through AdGuard Home"
echo

info "5. Test Samba access:"
echo "   - Windows: \\\\$SYSTEM_IP\\Shared"
echo "   - macOS: smb://$SYSTEM_IP/Shared"
echo "   - Linux: smb://$SYSTEM_IP/Shared"
echo

warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "For detailed instructions, see: $REPO_ROOT/README.md (Path B section)"
echo

success "Installation script completed successfully!"
