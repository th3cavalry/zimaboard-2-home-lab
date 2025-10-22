#!/bin/bash
################################################################################
# ZimaBoard Homelab - Environment Validation Script
# 
# This script validates that the .env file exists, all required variables are
# set, and that the configured paths are accessible and writable.
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Error and success counters
ERRORS=0
WARNINGS=0

# Logging functions
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Header
echo "=================================="
echo "  Environment Validation Script"
echo "=================================="
echo

# Get the script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repository root
cd "$REPO_ROOT"

################################################################################
# Step 1: Check if .env file exists
################################################################################

info "Step 1: Checking for .env file..."
if [[ ! -f .env ]]; then
    error ".env file not found!"
    echo "  Please create it by copying .env.example:"
    echo "  cp .env.example .env"
    echo
    exit 1
else
    success ".env file found"
fi
echo

################################################################################
# Step 2: Load and validate required variables
################################################################################

info "Step 2: Validating required environment variables..."

# Source the .env file
set -a
source .env
set +a

# Required variables
REQUIRED_VARS=(
    "SERVER_IP"
    "TIMEZONE"
    "DATA_PATH_SSD"
    "DATA_PATH_HDD"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required variable '$var' is not set or empty"
    else
        success "Variable '$var' is set: ${!var}"
    fi
done
echo

################################################################################
# Step 3: Validate IP address format
################################################################################

info "Step 3: Validating SERVER_IP format..."
if [[ -n "${SERVER_IP:-}" ]]; then
    if [[ $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        success "SERVER_IP has valid format: $SERVER_IP"
    else
        error "SERVER_IP has invalid format: $SERVER_IP"
        echo "  Expected format: xxx.xxx.xxx.xxx (e.g., 192.168.8.2)"
    fi
fi
echo

################################################################################
# Step 4: Validate timezone
################################################################################

info "Step 4: Validating TIMEZONE..."
if [[ -n "${TIMEZONE:-}" ]]; then
    if [[ -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
        success "TIMEZONE is valid: $TIMEZONE"
    else
        warning "TIMEZONE '$TIMEZONE' may not be valid"
        echo "  Check: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    fi
fi
echo

################################################################################
# Step 5: Check storage paths
################################################################################

info "Step 5: Checking storage paths..."

# Check SSD path
if [[ -n "${DATA_PATH_SSD:-}" ]]; then
    if [[ -d "$DATA_PATH_SSD" ]]; then
        success "SSD path exists: $DATA_PATH_SSD"
        
        # Check if mounted
        if mountpoint -q "$DATA_PATH_SSD" 2>/dev/null; then
            success "SSD path is a mount point"
        else
            warning "SSD path exists but is not a mount point"
            echo "  This may be intentional if you're using a subdirectory"
        fi
        
        # Check if writable
        if [[ -w "$DATA_PATH_SSD" ]]; then
            success "SSD path is writable"
        else
            error "SSD path is not writable by current user"
            echo "  Fix with: sudo bash scripts/fix-permissions.sh"
            echo "  Or manually: sudo chown -R $USER:$USER $DATA_PATH_SSD"
        fi
        
        # Check for fileshare subdirectory
        if [[ -d "$DATA_PATH_SSD/fileshare" ]]; then
            success "Fileshare directory exists: $DATA_PATH_SSD/fileshare"
            if [[ -w "$DATA_PATH_SSD/fileshare" ]]; then
                success "Fileshare directory is writable"
            else
                error "Fileshare directory is not writable"
                echo "  Fix with: sudo bash scripts/fix-permissions.sh"
                echo "  Or manually: sudo chmod -R 777 $DATA_PATH_SSD/fileshare"
            fi
        else
            warning "Fileshare directory not found: $DATA_PATH_SSD/fileshare"
            echo "  Create it with: sudo mkdir -p $DATA_PATH_SSD/fileshare"
            echo "                  sudo chmod -R 777 $DATA_PATH_SSD/fileshare"
        fi
    else
        error "SSD path does not exist: $DATA_PATH_SSD"
        echo "  Create and mount your SSD, then create the directory"
    fi
else
    error "DATA_PATH_SSD is not set"
fi
echo

# Check HDD path
if [[ -n "${DATA_PATH_HDD:-}" ]]; then
    if [[ -d "$DATA_PATH_HDD" ]]; then
        success "HDD path exists: $DATA_PATH_HDD"
        
        # Check if mounted
        if mountpoint -q "$DATA_PATH_HDD" 2>/dev/null; then
            success "HDD path is a mount point"
        else
            warning "HDD path exists but is not a mount point"
            echo "  This may be intentional if you're using a subdirectory"
        fi
        
        # Check if writable
        if [[ -w "$DATA_PATH_HDD" ]]; then
            success "HDD path is writable"
        else
            error "HDD path is not writable by current user"
            echo "  Fix with: sudo bash scripts/fix-permissions.sh"
            echo "  Or manually: sudo chown -R $USER:$USER $DATA_PATH_HDD"
        fi
        
        # Check for lancache subdirectories
        if [[ -d "$DATA_PATH_HDD/lancache" ]]; then
            success "Lancache directory exists: $DATA_PATH_HDD/lancache"
            if [[ -w "$DATA_PATH_HDD/lancache" ]]; then
                success "Lancache directory is writable"
            else
                error "Lancache directory is not writable"
                echo "  Fix with: sudo bash scripts/fix-permissions.sh"
                echo "  Or manually: sudo chmod -R 777 $DATA_PATH_HDD/lancache"
            fi
        else
            warning "Lancache directory not found: $DATA_PATH_HDD/lancache"
            echo "  Create it with: sudo mkdir -p $DATA_PATH_HDD/lancache"
            echo "                  sudo chmod -R 777 $DATA_PATH_HDD/lancache"
        fi
        
        if [[ -d "$DATA_PATH_HDD/lancache-logs" ]]; then
            success "Lancache logs directory exists: $DATA_PATH_HDD/lancache-logs"
        else
            warning "Lancache logs directory not found: $DATA_PATH_HDD/lancache-logs"
            echo "  Create it with: sudo mkdir -p $DATA_PATH_HDD/lancache-logs"
            echo "                  sudo chmod -R 777 $DATA_PATH_HDD/lancache-logs"
        fi
    else
        error "HDD path does not exist: $DATA_PATH_HDD"
        echo "  Create and mount your HDD, then create the directory"
    fi
else
    error "DATA_PATH_HDD is not set"
fi
echo

################################################################################
# Step 6: Check Docker
################################################################################

info "Step 6: Checking Docker installation..."
if command -v docker &> /dev/null; then
    success "Docker is installed"
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    info "Docker version: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        success "Docker daemon is running"
    else
        error "Docker daemon is not running"
        echo "  Start it with: sudo systemctl start docker"
    fi
else
    error "Docker is not installed"
    echo "  Install Docker following the README instructions"
fi
echo

if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    success "Docker Compose is installed"
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
    info "Docker Compose version: $COMPOSE_VERSION"
else
    error "Docker Compose is not installed"
    echo "  Install Docker Compose following the README instructions"
fi
echo

################################################################################
# Step 7: Check port availability
################################################################################

info "Step 7: Checking if required ports are available..."

check_port() {
    local port=$1
    local service=$2
    if sudo lsof -i :$port &> /dev/null; then
        warning "Port $port is already in use (needed for $service)"
        echo "  Process using port: $(sudo lsof -i :$port | tail -1 | awk '{print $1}')"
    else
        success "Port $port is available ($service)"
    fi
}

check_port 53 "AdGuard DNS"
check_port 3000 "AdGuard Web Interface"
check_port 8080 "Lancache HTTP"
check_port 8443 "Lancache HTTPS"
check_port 445 "Samba"
echo

################################################################################
# Summary
################################################################################

echo "=================================="
echo "         Validation Summary"
echo "=================================="
echo

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "Your environment is properly configured."
    echo "You can now run: docker compose up -d"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}"
    echo "Review the warnings above. You may still be able to proceed."
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Please fix the errors above before deploying services."
    exit 1
fi

echo
