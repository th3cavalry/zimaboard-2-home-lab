#!/bin/bash

# ZimaBoard 2 Homelab - Docker Installation Script
# Alternative deployment using Docker Compose

set -e

echo "🐳 ZimaBoard 2 Homelab - Docker Installation"
echo "============================================"
echo "Setting up homelab with Docker Compose..."
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  This script should NOT be run as root"
   echo "Please run as your regular user account"
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "🔧 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed successfully"
    echo "⚠️  Please log out and back in, then run this script again"
    exit 0
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "🔧 Installing Docker Compose..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
    echo "✅ Docker Compose installed successfully"
fi

echo "✅ Docker environment ready"
echo ""

# Download the repository if not already present
if [[ ! -f "docker-compose.yml" ]]; then
    echo "📥 Downloading ZimaBoard 2 homelab configuration..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd $TEMP_DIR
    
    # Download all necessary files
    echo "• Downloading docker-compose.yml..."
    curl -sSL "https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/docker-compose.yml" -o docker-compose.yml
    
    echo "• Downloading environment configuration..."
    curl -sSL "https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/.env.example" -o .env
    
    echo "• Creating directory structure..."
    mkdir -p config/{pihole,unbound,nginx,squid,seafile}
    mkdir -p data/{pihole,unbound,nginx,squid,seafile,netdata}
    mkdir -p logs
    
    # Move to final location
    INSTALL_DIR="$HOME/zimaboard-2-home-lab"
    echo "• Installing to: $INSTALL_DIR"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "⚠️  Directory already exists, backing up..."
        mv "$INSTALL_DIR" "$INSTALL_DIR.backup.$(date +%s)"
    fi
    
    mv $TEMP_DIR $INSTALL_DIR
    cd $INSTALL_DIR
    
    echo "✅ Configuration downloaded successfully"
else
    echo "✅ Configuration already present"
fi

echo ""

# Configure environment
echo "🔧 Configuring environment..."

# Get the local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "• Detected IP address: $LOCAL_IP"

# Update .env file with local IP
sed -i "s/ZIMABOARD_IP=.*/ZIMABOARD_IP=$LOCAL_IP/" .env

# Set proper permissions
sudo chown -R $USER:$USER .
chmod +x scripts/install/install.sh 2>/dev/null || true

echo "✅ Environment configured"
echo ""

# Start services
echo "🚀 Starting homelab services..."
docker compose up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 30

# Check service status
echo "🔍 Checking service status..."
docker compose ps

echo ""
echo "🎉 Docker Installation Complete!"
echo "================================"
echo ""
echo "🌐 Access your services at:"
echo "• Pi-hole Admin: http://$LOCAL_IP:8080/admin"
echo "• Seafile NAS: http://$LOCAL_IP:8081"
echo "• Netdata Monitoring: http://$LOCAL_IP:19999"
echo "• Squid Proxy: Configure devices to use $LOCAL_IP:3128"
echo ""
echo "🔐 Default credentials (CHANGE IMMEDIATELY):"
echo "• Pi-hole: admin / admin123"
echo "• Seafile: admin / admin123"
echo ""
echo "📚 For detailed configuration and management:"
echo "https://github.com/th3cavalry/zimaboard-2-home-lab"
echo ""
echo "🔧 Management commands:"
echo "• View logs: docker compose logs -f [service]"
echo "• Restart services: docker compose restart"
echo "• Stop services: docker compose down"
echo "• Update services: docker compose pull && docker compose up -d"
echo ""
echo "Happy homelabbing! 🏠🔒🚀"
