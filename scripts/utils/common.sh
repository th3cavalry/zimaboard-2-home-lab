#!/bin/bash
################################################################################
# Common Utilities for ZimaBoard 2 Homelab Installation
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Output Functions
################################################################################

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

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║ $1"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

################################################################################
# System Validation Functions
################################################################################

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
    export ARCH_TYPE
    print_info "Detected architecture: $ARCH_TYPE"
}

################################################################################
# Service Management Functions
################################################################################

service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "✅ Running"
    elif systemctl is-enabled --quiet "$service"; then
        echo "⏸️  Enabled (not running)"
    else
        echo "❌ Disabled"
    fi
}

wait_for_service() {
    local service="$1"
    local timeout="${2:-30}"
    local count=0
    
    print_info "Waiting for $service to start..."
    
    while [ $count -lt $timeout ]; do
        if systemctl is-active --quiet "$service"; then
            print_success "$service is running"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    print_error "$service failed to start within $timeout seconds"
    systemctl status "$service" --no-pager
    return 1
}

################################################################################
# Storage Functions
################################################################################

is_ssd_available() {
    [[ -d "/mnt/ssd-data" ]] && mountpoint -q "/mnt/ssd-data"
}

get_data_dir() {
    if is_ssd_available; then
        echo "/mnt/ssd-data"
    else
        echo "/opt/homelab-data"
    fi
}

ensure_data_dir() {
    local service="$1"
    local data_dir
    data_dir=$(get_data_dir)
    
    mkdir -p "$data_dir/$service"
    
    # Set appropriate ownership based on service
    case "$service" in
        "nextcloud")
            chown -R www-data:www-data "$data_dir/$service"
            ;;
        "adguardhome")
            chown -R root:root "$data_dir/$service"
            ;;
        *)
            chown -R root:root "$data_dir/$service"
            ;;
    esac
    
    echo "$data_dir/$service"
}

################################################################################
# Network Functions
################################################################################

check_port() {
    local port="$1"
    if ss -tlnp | grep -q ":$port "; then
        print_warning "Port $port is already in use"
        return 1
    else
        return 0
    fi
}

wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local count=0
    
    print_info "Waiting for port $port to be available..."
    
    while [ $count -lt $timeout ]; do
        if ss -tlnp | grep -q ":$port "; then
            print_success "Port $port is available"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    print_error "Port $port not available within $timeout seconds"
    return 1
}

################################################################################
# Configuration Functions
################################################################################

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up $file"
    fi
}

download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Downloading $url (attempt $attempt/$max_attempts)"
        
        if wget -O "$output" "$url"; then
            print_success "Downloaded successfully"
            return 0
        else
            print_warning "Download failed, retrying..."
            rm -f "$output"
            ((attempt++))
            sleep 2
        fi
    done
    
    print_error "Failed to download after $max_attempts attempts"
    return 1
}

################################################################################
# Validation Functions
################################################################################

validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

check_disk_space() {
    local required_gb="$1"
    local path="${2:-/}"
    
    local available_kb
    available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        print_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    else
        print_info "Disk space check passed. Available: ${available_gb}GB"
        return 0
    fi
}

################################################################################
# Error Handling
################################################################################

set_error_handling() {
    set -euo pipefail
    trap 'handle_error $? $LINENO' ERR
}

handle_error() {
    local exit_code=$1
    local line_number=$2
    
    print_error "Script failed with exit code $exit_code at line $line_number"
    print_error "Check the logs above for details"
    
    # Cleanup if needed
    cleanup_on_error
    
    exit $exit_code
}

cleanup_on_error() {
    # Override this function in individual modules if cleanup is needed
    print_info "Performing cleanup..."
}

################################################################################
# Logging Functions
################################################################################

setup_logging() {
    local log_file="${1:-/tmp/homelab-install.log}"
    exec 1> >(tee -a "$log_file")
    exec 2> >(tee -a "$log_file" >&2)
    print_info "Logging to $log_file"
}

log_command() {
    local cmd="$1"
    print_info "Executing: $cmd"
    eval "$cmd"
}

################################################################################
# Module Loading
################################################################################

load_module_config() {
    local module="$1"
    local config_file="scripts/config/${module}.conf"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        print_info "Loaded configuration for $module"
    fi
}

################################################################################
# Progress Tracking
################################################################################

show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled_length=$((current * bar_length / total))
    
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    printf "\r${BLUE}[%3d%%]${NC} [%s] %s" "$percent" "$bar" "$description"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

################################################################################
# System Information
################################################################################

get_system_info() {
    print_info "System Information:"
    echo "  OS: $(lsb_release -d | cut -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $ARCH_TYPE"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "  Disk: $(df -h / | awk 'NR==2 {print $2}')"
}

################################################################################
# Export all functions
################################################################################

# Make functions available to sourcing scripts
export -f print_info print_success print_warning print_error print_header
export -f check_root check_ubuntu detect_architecture
export -f service_status wait_for_service
export -f is_ssd_available get_data_dir ensure_data_dir
export -f check_port wait_for_port
export -f backup_file download_with_retry
export -f validate_ip check_disk_space
export -f set_error_handling handle_error cleanup_on_error
export -f setup_logging log_command
export -f load_module_config
export -f show_progress
export -f get_system_info
