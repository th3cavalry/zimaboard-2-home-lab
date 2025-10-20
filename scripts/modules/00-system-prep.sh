#!/bin/bash
################################################################################
# ZimaBoard 2 Homelab - Module 00: System Preparation
#
# This module prepares the system for homelab services:
# - Updates packages
# - Installs essential packages
# - Configures swap settings
# - Sets up directory structure
# - Optimizes system settings
################################################################################

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

################################################################################
# Module Configuration
################################################################################

MODULE_NAME="System Preparation"
MODULE_VERSION="1.0.0"

################################################################################
# System Package Updates
################################################################################

update_system_packages() {
    print_step "Updating system packages"
    
    show_progress "Updating package database..." 30
    apt-get update
    
    show_progress "Upgrading existing packages..." 60
    apt-get upgrade -y
    
    show_progress "Installing security updates..." 90
    apt-get dist-upgrade -y
    
    print_success "System packages updated"
}

install_essential_packages() {
    print_step "Installing essential packages"
    
    local packages=(
        "curl"
        "wget" 
        "unzip"
        "htop"
        "tree"
        "nano"
        "vim"
        "git"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "ufw"
        "fail2ban"
        "rsync"
        "cron"
        "logrotate"
        "dnsutils"
        "net-tools"
        "iotop"
        "iftop"
        "ncdu"
    )
    
    print_info "Installing ${#packages[@]} essential packages..."
    
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        ((current++))
        local progress=$((current * 100 / total))
        show_progress "Installing $package..." $progress
        
        if ! package_is_installed "$package"; then
            apt-get install -y "$package"
        else
            print_info "$package is already installed"
        fi
    done
    
    print_success "Essential packages installed"
}

################################################################################
# System Optimization
################################################################################

configure_swap_settings() {
    print_step "Configuring swap settings for SSD optimization"
    
    # Reduce swappiness for SSD longevity
    local swappiness=10
    local cache_pressure=50
    
    print_info "Setting vm.swappiness to $swappiness"
    sysctl vm.swappiness=$swappiness
    
    print_info "Setting vm.vfs_cache_pressure to $cache_pressure"
    sysctl vm.vfs_cache_pressure=$cache_pressure
    
    # Make settings permanent
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$swappiness" >> /etc/sysctl.conf
    else
        sed -i "s/vm.swappiness=.*/vm.swappiness=$swappiness/" /etc/sysctl.conf
    fi
    
    if ! grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=$cache_pressure" >> /etc/sysctl.conf
    else
        sed -i "s/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=$cache_pressure/" /etc/sysctl.conf
    fi
    
    print_success "Swap settings optimized for SSD"
}

setup_directory_structure() {
    print_step "Setting up homelab directory structure"
    
    local directories=(
        "/opt/homelab"
        "/opt/homelab/scripts"
        "/opt/homelab/configs"
        "/opt/homelab/logs"
        "/opt/homelab/backups"
        "/opt/homelab-data"
        "/var/log/homelab"
    )
    
    for dir in "${directories[@]}"; do
        ensure_directory "$dir"
        print_info "Created directory: $dir"
    done
    
    # Set proper ownership and permissions
    chown -R root:root /opt/homelab
    chmod -R 755 /opt/homelab
    
    chown -R root:adm /var/log/homelab
    chmod -R 755 /var/log/homelab
    
    print_success "Directory structure created"
}

################################################################################
# Storage Optimization
################################################################################

optimize_storage_settings() {
    print_step "Optimizing storage settings"
    
    # Check if SSD is available
    if is_ssd_available; then
        print_info "SSD detected - applying SSD-specific optimizations"
        
        # Add noatime to fstab entries to reduce SSD writes
        backup_file "/etc/fstab"
        
        if ! grep -q "noatime" /etc/fstab; then
            print_info "Adding noatime mount option to reduce SSD writes"
            sed -i 's/\(defaults\)/\1,noatime/g' /etc/fstab
        fi
        
        # Set up SSD TRIM if available
        if command -v fstrim >/dev/null 2>&1; then
            print_info "Setting up weekly SSD TRIM"
            systemctl enable fstrim.timer
        fi
    else
        print_info "No SSD detected - using standard storage optimizations"
    fi
    
    print_success "Storage settings optimized"
}

################################################################################
# Security Configuration
################################################################################

configure_basic_firewall() {
    print_step "Configuring basic firewall rules"
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (essential for remote access)
    ufw allow ssh
    
    # Allow common web ports for later services
    ufw allow 80/tcp   # HTTP
    ufw allow 443/tcp  # HTTPS
    
    # Enable firewall
    ufw --force enable
    
    print_success "Basic firewall configured"
}

configure_fail2ban() {
    print_step "Configuring Fail2Ban for SSH protection"
    
    # Create custom SSH jail
    cat > /etc/fail2ban/jail.local << 'JAIL_EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
JAIL_EOF
    
    # Start and enable Fail2Ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    print_success "Fail2Ban configured for SSH protection"
}

################################################################################
# System Information and Logging
################################################################################

setup_logging() {
    print_step "Setting up enhanced logging"
    
    # Create homelab-specific logrotate configuration
    cat > /etc/logrotate.d/homelab << 'LOGROTATE_EOF'
/var/log/homelab/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_EOF
    
    print_success "Enhanced logging configured"
}

collect_system_info() {
    print_step "Collecting system information"
    
    local info_file="/opt/homelab/system-info.txt"
    
    cat > "$info_file" << INFO_EOF
ZimaBoard 2 Homelab System Information
Generated: $(date)
======================================

Hardware Information:
$(detect_hardware_info)

Network Information:
$(get_network_info)

Storage Information:
$(get_storage_info)

System Information:
OS: $(get_os_info)
Architecture: $(detect_architecture)
Kernel: $(uname -r)
Uptime: $(uptime -p)
Load Average: $(uptime | cut -d',' -f4-6)

Memory Information:
$(free -h)

Disk Usage:
$(df -h)
INFO_EOF
    
    print_success "System information collected in $info_file"
}

################################################################################
# Module Validation
################################################################################

validate_system_prep() {
    print_step "Validating system preparation"
    
    local errors=()
    
    # Check essential packages
    local required_packages=("curl" "wget" "ufw" "fail2ban")
    for package in "${required_packages[@]}"; do
        if ! package_is_installed "$package"; then
            errors+=("Required package $package is not installed")
        fi
    done
    
    # Check directory structure
    local required_dirs=("/opt/homelab" "/opt/homelab-data" "/var/log/homelab")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            errors+=("Required directory $dir does not exist")
        fi
    done
    
    # Check firewall status
    if ! ufw status | grep -q "Status: active"; then
        errors+=("UFW firewall is not active")
    fi
    
    # Check Fail2Ban status
    if ! systemctl is-active --quiet fail2ban; then
        errors+=("Fail2Ban is not running")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        print_success "System preparation validation passed"
        return 0
    else
        print_error "System preparation validation failed:"
        for error in "${errors[@]}"; do
            print_error "  • $error"
        done
        return 1
    fi
}

################################################################################
# Main Module Function
################################################################################

main() {
    print_module_header "$MODULE_NAME" "$MODULE_VERSION"
    
    # Pre-checks
    check_root
    check_ubuntu
    
    local start_time=$(date +%s)
    
    # System updates and packages
    update_system_packages
    install_essential_packages
    
    # System optimization
    configure_swap_settings
    optimize_storage_settings
    
    # Directory structure
    setup_directory_structure
    
    # Security configuration
    configure_basic_firewall
    configure_fail2ban
    
    # Logging and information
    setup_logging
    collect_system_info
    
    # Validation
    if validate_system_prep; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        print_module_footer "$MODULE_NAME" "$duration"
        
        # Log success
        log_action "SYSTEM_PREP" "System preparation completed successfully in ${duration}s"
        
        return 0
    else
        print_error "System preparation failed validation"
        log_action "SYSTEM_PREP" "System preparation failed validation" "ERROR"
        return 1
    fi
}

# Handle direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
