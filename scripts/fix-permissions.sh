#!/bin/bash
################################################################################
# ZimaBoard Homelab - Storage Permissions Fix Script
# 
# This script fixes permissions on storage directories that are not writable
# by the current user. It's designed to be run when the validate-env.sh script
# reports permission errors.
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Header
echo "=================================="
echo "  Storage Permissions Fix Script"
echo "=================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (with sudo)"
    echo "  Usage: sudo bash scripts/fix-permissions.sh"
    exit 1
fi

# Get the script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repository root
cd "$REPO_ROOT"

# Check if .env file exists
if [[ ! -f .env ]]; then
    error ".env file not found!"
    echo "  Please create it by copying .env.example:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
set -a
source .env
set +a

# Get the actual user who invoked sudo
ACTUAL_USER="${SUDO_USER:-$USER}"

if [[ "$ACTUAL_USER" == "root" ]]; then
    error "Cannot determine the actual user (script was run directly as root)"
    echo "  Please run this script with sudo as a regular user:"
    echo "  sudo bash scripts/fix-permissions.sh"
    exit 1
fi

info "Fixing permissions for user: $ACTUAL_USER"
echo

################################################################################
# Fix SSD permissions
################################################################################

if [[ -n "${DATA_PATH_SSD:-}" ]]; then
    if [[ -d "$DATA_PATH_SSD" ]]; then
        info "Fixing permissions for SSD path: $DATA_PATH_SSD"
        
        # Set ownership
        chown -R $ACTUAL_USER:$ACTUAL_USER "$DATA_PATH_SSD"
        
        # Verify it's now writable
        if sudo -u $ACTUAL_USER test -w "$DATA_PATH_SSD"; then
            success "SSD path is now writable by $ACTUAL_USER"
        else
            error "Failed to make SSD path writable"
        fi
        
        # Ensure fileshare subdirectory has correct permissions
        if [[ -d "$DATA_PATH_SSD/fileshare" ]]; then
            info "Setting fileshare directory permissions to 777"
            chmod -R 777 "$DATA_PATH_SSD/fileshare"
            success "Fileshare directory permissions updated"
        fi
    else
        warning "SSD path does not exist: $DATA_PATH_SSD"
    fi
else
    warning "DATA_PATH_SSD is not set in .env file"
fi

echo

################################################################################
# Fix HDD permissions
################################################################################

if [[ -n "${DATA_PATH_HDD:-}" ]]; then
    if [[ -d "$DATA_PATH_HDD" ]]; then
        info "Fixing permissions for HDD path: $DATA_PATH_HDD"
        
        # Set ownership
        chown -R $ACTUAL_USER:$ACTUAL_USER "$DATA_PATH_HDD"
        
        # Verify it's now writable
        if sudo -u $ACTUAL_USER test -w "$DATA_PATH_HDD"; then
            success "HDD path is now writable by $ACTUAL_USER"
        else
            error "Failed to make HDD path writable"
        fi
        
        # Ensure lancache subdirectories have correct permissions
        if [[ -d "$DATA_PATH_HDD/lancache" ]]; then
            info "Setting lancache directory permissions to 777"
            chmod -R 777 "$DATA_PATH_HDD/lancache"
            success "Lancache directory permissions updated"
        fi
        
        if [[ -d "$DATA_PATH_HDD/lancache-logs" ]]; then
            info "Setting lancache-logs directory permissions to 777"
            chmod -R 777 "$DATA_PATH_HDD/lancache-logs"
            success "Lancache-logs directory permissions updated"
        fi
    else
        warning "HDD path does not exist: $DATA_PATH_HDD"
    fi
else
    warning "DATA_PATH_HDD is not set in .env file"
fi

echo

################################################################################
# Summary
################################################################################

echo "=================================="
echo "         Fix Complete"
echo "=================================="
echo

success "Storage permissions have been updated for user: $ACTUAL_USER"
echo
info "Run the validation script to verify:"
echo "  bash scripts/validate-env.sh"
echo
