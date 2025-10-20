#!/bin/bash
################################################################################
# ZimaBoard 2 Homelab - Main Installation Script
# 
# This script deploys a complete security homelab on Ubuntu Server 24.04 LTS
# optimized for ZimaBoard 2 with eMMC + SSD storage
#
# Usage: sudo ./install.sh
# Or: curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="2.0.0"
REPO_URL="https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         ZimaBoard 2 Homelab Installation v${VERSION}          ║"
    echo "║         Ubuntu Server 24.04 LTS Edition                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script requires Ubuntu Server"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        print_warning "This script is designed for Ubuntu 24.04 LTS (you have $VERSION_ID)"
        read -p "Continue anyway? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
    fi
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l)
            ARCH_TYPE="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    print_info "Detected architecture: $ARCH_TYPE"
}

################################################################################
# Main Installation
################################################################################

main() {
    print_header
    check_root
    check_ubuntu
    detect_architecture
    
    print_info "Starting installation..."
    print_info "This will install: AdGuard Home, Nextcloud, WireGuard, Squid, Netdata, Nginx"
    echo ""
    read -p "Continue with installation? (y/N): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # TODO: Download and execute the actual installation modules
    # For now, this is a placeholder that references the old script
    
    print_info "Fetching installation modules..."
    
    # In the next phase, we'll modularize the installation into separate scripts:
    # - scripts/modules/01-system-prep.sh
    # - scripts/modules/02-ssd-setup.sh
    # - scripts/modules/03-adguard.sh
    # - scripts/modules/04-nextcloud.sh
    # - scripts/modules/05-wireguard.sh
    # - scripts/modules/06-squid.sh
    # - scripts/modules/07-netdata.sh
    # - scripts/modules/08-nginx.sh
    # - scripts/modules/09-finalize.sh
    
    print_warning "Installation script is currently being modularized"
    print_info "For now, please use the old installation method from the backup branch:"
    echo ""
    echo "  git clone -b backup-before-recreation https://github.com/th3cavalry/zimaboard-2-home-lab.git"
    echo "  cd zimaboard-2-home-lab"
    echo "  sudo ./scripts/simple-install/ubuntu-homelab-simple.sh"
    echo ""
    
    print_info "Repository recreation in progress - stay tuned!"
}

# Run main function
main "$@"
