#!/bin/bash
################################################################################
# System Preparation Module
# Part of ZimaBoard 2 Homelab Installation System
################################################################################

prepare_system() {
    print_info "🔧 Preparing Ubuntu system for homelab installation..."
    
    # Update system packages
    print_info "Updating system packages..."
    apt update && apt upgrade -y
    
    # Install essential packages
    print_info "Installing essential packages..."
    apt install -y \
        curl wget git htop iotop tree \
        unzip bzip2 zip \
        dnsutils net-tools \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw fail2ban \
        unattended-upgrades \
        sqlite3 \
        python3 python3-pip \
        nodejs npm
    
    # Configure UFW firewall
    print_info "🔥 Configuring UFW firewall..."
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh comment "SSH access"
    
    # Configure automatic security updates
    print_info "🔒 Configuring automatic security updates..."
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UPDATE_EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UPDATE_EOF
    
    systemctl enable unattended-upgrades
    
    # Configure fail2ban
    print_info "🛡️ Configuring fail2ban..."
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # eMMC optimizations
    print_info "📱 Applying eMMC longevity optimizations..."
    
    # Reduce swap usage
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    
    # Add noatime to reduce eMMC writes
    if ! grep -q "noatime" /etc/fstab; then
        cp /etc/fstab /etc/fstab.backup
        sed -i 's/errors=remount-ro/errors=remount-ro,noatime/' /etc/fstab
        print_success "Added noatime to root filesystem"
    fi
    
    # Configure log rotation for reduced writes
    cat > /etc/logrotate.d/homelab << 'LOGROTATE_EOF'
/var/log/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
LOGROTATE_EOF
    
    # Apply sysctl changes
    sysctl -p
    
    print_success "✅ System preparation completed"
    print_info "   - Firewall: Enabled with basic rules"
    print_info "   - Security updates: Automatic"
    print_info "   - eMMC optimizations: Applied"
    print_info "   - Fail2ban: Active protection"
    
    return 0
}

# Export function for use by main installer
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f prepare_system
fi
