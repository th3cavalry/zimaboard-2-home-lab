#!/bin/bash

# ZimaBoard 2 Homelab Installation Script
# This script sets up the complete security homelab environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons."
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check available memory (should have at least 8GB for comfortable operation)
    available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_mem" -lt 4096 ]; then
        warn "Available memory is less than 4GB. Some services may struggle."
    fi
    
    # Check disk space (should have at least 20GB free)
    available_disk=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 20 ]; then
        error "Available disk space is less than 20GB. Please free up space."
        exit 1
    fi
    
    info "System requirements check passed."
}

# Install Docker and Docker Compose
install_docker() {
    log "Installing Docker and Docker Compose..."
    
    if ! command -v docker &> /dev/null; then
        info "Installing Docker..."
        
        # Update package index
        sudo apt-get update
        
        # Install dependencies
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        info "Docker installed successfully. Please log out and log back in for group changes to take effect."
    else
        info "Docker is already installed."
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        info "Docker Compose is already installed."
    fi
}

# Set up system optimizations
optimize_system() {
    log "Applying system optimizations for homelab..."
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Optimize network settings for security monitoring
    sudo tee -a /etc/sysctl.conf <<EOL

# ZimaBoard Homelab Optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOL
    
    # Apply sysctl settings
    sudo sysctl -p
    
    info "System optimizations applied."
}

# Create necessary directories
create_directories() {
    log "Creating directory structure..."
    
    # Set proper permissions
    chmod -R 755 config/
    chmod -R 755 scripts/
    
    # Create data directories with proper permissions
    sudo mkdir -p data/{pihole,unbound,clamav,suricata,prometheus,grafana,portainer}
    sudo chown -R $USER:$USER data/
    
    # Create log directories
    sudo mkdir -p logs/{pihole,unbound,clamav,suricata,nginx,prometheus,grafana}
    sudo chown -R $USER:$USER logs/
    
    info "Directory structure created."
}

# Download Suricata rules
setup_suricata_rules() {
    log "Setting up Suricata rules..."
    
    mkdir -p config/suricata/rules
    
    # Download Emerging Threats rules (free)
    curl -L "https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz" -o /tmp/emerging.rules.tar.gz
    
    if [ -f "/tmp/emerging.rules.tar.gz" ]; then
        tar -xzf /tmp/emerging.rules.tar.gz -C /tmp/
        cp /tmp/rules/*.rules config/suricata/rules/
        
        # Create a combined rules file
        cat config/suricata/rules/*.rules > config/suricata/rules/suricata.rules
        
        rm -rf /tmp/emerging.rules.tar.gz /tmp/rules
        
        info "Suricata rules downloaded and configured."
    else
        warn "Failed to download Suricata rules. You'll need to set them up manually."
    fi
}

# Start the homelab services
start_services() {
    log "Starting homelab services..."
    
    # Pull latest images
    docker-compose pull
    
    # Start services in correct order
    docker-compose up -d unbound
    sleep 10
    
    docker-compose up -d pihole
    sleep 15
    
    docker-compose up -d clamav
    sleep 10
    
    docker-compose up -d suricata
    sleep 5
    
    docker-compose up -d prometheus grafana
    sleep 10
    
    docker-compose up -d portainer nginx
    
    info "All services started successfully!"
}

# Display service information
show_service_info() {
    log "Homelab services are now running!"
    
    echo ""
    echo "🏠 ZimaBoard 2 Homelab - Service Access URLs"
    echo "============================================="
    echo ""
    echo "📊 Main Dashboard:      http://$(hostname -I | awk '{print $1}'):80"
    echo "🛡️  Pi-hole Admin:       http://$(hostname -I | awk '{print $1}'):8080/admin"
    echo "🐋 Portainer:          http://$(hostname -I | awk '{print $1}'):9000"
    echo "📈 Grafana:            http://$(hostname -I | awk '{print $1}'):3000"
    echo "📊 Prometheus:         http://$(hostname -I | awk '{print $1}'):9090"
    echo ""
    echo "🔐 Default Credentials:"
    echo "   Pi-hole:    admin / admin123"
    echo "   Grafana:    admin / admin123"
    echo "   Portainer:  (Set on first login)"
    echo ""
    echo "⚠️  IMPORTANT: Change all default passwords!"
    echo ""
    echo "📋 Service Status:"
    docker-compose ps
    echo ""
    echo "🔧 To manage services:"
    echo "   Start:   docker-compose up -d"
    echo "   Stop:    docker-compose down"
    echo "   Logs:    docker-compose logs -f [service]"
    echo "   Restart: docker-compose restart [service]"
    echo ""
}

# Main installation process
main() {
    log "Starting ZimaBoard 2 Homelab Installation..."
    
    check_root
    check_requirements
    install_docker
    optimize_system
    create_directories
    setup_suricata_rules
    
    log "Installation completed. Starting services..."
    start_services
    
    sleep 30  # Give services time to fully start
    show_service_info
    
    log "ZimaBoard 2 Homelab installation completed successfully! 🎉"
}

# Run main function
main "$@"
