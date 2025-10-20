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

download_module() {
    local module_name=$1
    local module_path="scripts/modules/${module_name}"
    
    if [[ -f "$module_path" ]]; then
        # Local installation
        source "$module_path"
    else
        # Remote installation - download from GitHub
        print_info "Downloading module: $module_name"
        curl -fsSL "${REPO_URL}/${module_path}" -o "/tmp/${module_name}"
        source "/tmp/${module_name}"
        rm -f "/tmp/${module_name}"
    fi
}

main() {
    print_header
    check_root
    check_ubuntu
    detect_architecture
    
    print_info "Starting ZimaBoard 2 Homelab installation..."
    print_info "Services to install: AdGuard Home, Nextcloud, WireGuard, Squid, Netdata, Nginx"
    echo ""
    
    # Show system information
    print_info "System Information:"
    echo "  - OS: $(lsb_release -d | cut -f2)"
    echo "  - Architecture: $ARCH_TYPE"
    echo "  - Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "  - Storage: $(df -h / | tail -1 | awk '{print $4}') available"
    echo ""
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Set up error handling
    set -e
    trap 'print_error "Installation failed at line $LINENO. Check the logs above."' ERR
    
    # Export common variables for modules
    export DATA_DIR="/opt/homelab-data"
    export SSD_AVAILABLE=false
    
    print_info "🚀 Beginning modular installation..."
    
    # Phase 1: System preparation
    print_info "📦 Phase 1: System preparation"
    download_module "01-system-prep.sh"
    prepare_system
    
    # Phase 2: Storage setup
    print_info "💾 Phase 2: Storage configuration"
    download_module "02-storage-setup.sh"
    setup_storage
    
    # Phase 3: AdGuard Home
    print_info "🛡️ Phase 3: DNS filtering"
    download_module "03-adguard.sh"
    install_adguard
    
    # Phase 4: Nextcloud
    print_info "☁️ Phase 4: Personal cloud"
    download_module "04-nextcloud.sh"
    install_nextcloud
    
    # Phase 5: WireGuard VPN
    print_info "🔐 Phase 5: VPN server"
    download_module "05-wireguard.sh"
    install_wireguard
    
    # Phase 6: Squid proxy
    print_info "🔄 Phase 6: Bandwidth optimization"
    download_module "06-squid.sh"
    install_squid
    
    # Phase 7: Netdata monitoring
    print_info "📊 Phase 7: System monitoring"
    download_module "07-netdata.sh"
    install_netdata
    
    # Phase 8: Nginx web server
    print_info "🌐 Phase 8: Web dashboard"
    download_module "08-nginx.sh"
    install_nginx
    
    # Phase 9: Finalization
    print_info "⚡ Phase 9: Final configuration"
    download_module "09-finalize.sh"
    finalize_installation
    
    # Installation complete
    print_success "🎉 ZimaBoard 2 Homelab installation completed successfully!"
    echo ""
    print_info "📋 Your homelab is ready at:"
    echo "  🌐 Main Dashboard:    http://192.168.8.2"
    echo "  🛡️ AdGuard Home:      http://192.168.8.2:3000"
    echo "  ☁️ Nextcloud:         http://192.168.8.2:8000"
    echo "  📊 Netdata:           http://192.168.8.2:19999"
    echo ""
    print_warning "⚠️ IMPORTANT: Change default passwords immediately!"
    print_info "   - AdGuard Home: admin / admin123"
    print_info "   - Nextcloud: admin / admin123"
    echo ""
    print_success "🚀 Your ZimaBoard 2 homelab is ready to use!"
}

# Run main function
main "$@"
