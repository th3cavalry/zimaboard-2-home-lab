# Changelog

All notable changes to the ZimaBoard 2 Ultimate Homelab project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automated backup system for Nextcloud data
- Performance monitoring dashboard
- Custom DNS record management
- Gaming cache statistics
- Mobile app configuration guides

### Changed
- Improved error handling in installation script
- Enhanced security configurations
- Better storage detection logic

### Fixed
- Storage mounting issues on various drive configurations
- Nginx cache directory permissions
- AdGuard Home configuration validation

## [1.0.0] - 2025-01-XX

### Added
- Initial release of ZimaBoard 2 Ultimate Homelab
- Complete automated installation script (`install.sh`)
- AdGuard Home DNS filtering and ad blocking
  - Network-wide ad protection
  - Malware and phishing protection
  - Custom DNS filtering lists
  - Gaming and streaming service optimization
- Nginx web server with intelligent caching
  - Gaming download cache (Steam, Epic, Origin)
  - Streaming content optimization
  - Web content caching for faster browsing
- Nextcloud personal cloud platform
  - 1TB SSD storage for user data
  - File synchronization across devices
  - Web-based file management
  - Calendar and contacts integration
- Beautiful responsive web dashboard
  - Service status monitoring
  - Quick access to all services
  - System information display
  - Modern glassmorphism design
- Comprehensive security features
  - UFW firewall configuration
  - Fail2ban intrusion detection
  - Security headers and SSL preparation
  - Port security and access control
- Storage optimization for ZimaBoard 2
  - Automatic detection of eMMC, SSD, and HDD
  - Intelligent storage allocation
  - Optimal filesystem configurations
  - NOATIME mount options for SSD longevity
- Docker Compose alternative installation
  - Containerized service deployment
  - Easy scaling and management
  - Automatic updates with Watchtower
  - Homepage dashboard integration
- Complete uninstallation script (`uninstall.sh`)
  - Safe removal of all services
  - Data preservation options
  - Clean system restoration
- Comprehensive documentation
  - Detailed README with setup instructions
  - Hardware optimization guides
  - Troubleshooting documentation
  - Service configuration examples
- Environment configuration system
  - `.env.example` template
  - Customizable service settings
  - Security and performance tuning options

### Technical Specifications
- **Operating System**: Ubuntu Server 24.04 LTS
- **Hardware Support**: ZimaBoard 2 (Intel N100, 16GB RAM)
- **Storage**: 64GB eMMC + 2TB SSD + 500GB HDD configuration
- **Services**: AdGuard Home 0.107+, Nginx 1.24+, Nextcloud 28+
- **Security**: UFW firewall, Fail2ban, comprehensive DNS filtering
- **Performance**: Optimized for low-power ARM/x64 hardware

### Features
- 🛡️ **Network-wide Ad Blocking**: Block ads across all devices on your network
- 🎮 **Gaming Cache**: Cache Steam, Epic Games, and Origin downloads
- 📺 **Streaming Optimization**: Intelligent caching for YouTube and streaming services
- ☁️ **Personal Cloud**: 1TB secure cloud storage with Nextcloud
- 🏠 **Beautiful Dashboard**: Modern web interface for service management
- 🔒 **Advanced Security**: Multi-layer protection with DNS filtering and firewall
- ⚡ **Performance Optimized**: Tuned specifically for ZimaBoard 2 hardware
- 🔧 **Easy Installation**: One-command automated setup
- 📱 **Mobile Ready**: Works perfectly with mobile apps and devices

### Installation
```bash
# Quick installation
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash

# Or clone and run locally
git clone https://github.com/th3cavalry/zimaboard-2-home-lab.git
cd zimaboard-2-home-lab
sudo ./install.sh
```

### System Requirements
- **Hardware**: ZimaBoard 2 or compatible x64/ARM device
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 500GB minimum (multi-drive setup recommended)
- **OS**: Ubuntu Server 24.04 LTS (fresh installation)
- **Network**: Ethernet connection with internet access

### Default Ports
- **Dashboard**: Port 80 (HTTP)
- **AdGuard Home**: Port 3000 (Web UI), Port 53 (DNS)
- **Nextcloud**: Port 8080 (Web UI)
- **SSH**: Port 22 (System access)

### Post-Installation
1. Configure AdGuard Home at `http://your-ip:3000`
2. Set up Nextcloud admin account at `http://your-ip:8080`
3. Update router DNS settings to point to your ZimaBoard IP
4. Install Nextcloud mobile apps for file synchronization
5. Configure gaming clients to use cache (automatic)

### Known Issues
- First-time DNS filtering may take 5-10 minutes to fully activate
- Gaming cache shows maximum benefit after initial downloads
- Large file uploads to Nextcloud may timeout (configurable)

### Credits
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) for DNS filtering
- [Nextcloud](https://github.com/nextcloud/server) for personal cloud platform
- [Nginx](https://nginx.org/) for web server and caching
- [Hagezi DNS Blocklists](https://github.com/hagezi/dns-blocklists) for comprehensive ad blocking
- Community feedback and testing from ZimaBoard users

---

## Version Numbering

- **Major.Minor.Patch** (e.g., 1.0.0)
- **Major**: Breaking changes, new architecture
- **Minor**: New features, service additions
- **Patch**: Bug fixes, security updates, configuration improvements

## Support

For issues, feature requests, or contributions:
- 🐛 **Issues**: [GitHub Issues](https://github.com/th3cavalry/zimaboard-2-home-lab/issues)
- 💡 **Features**: [GitHub Discussions](https://github.com/th3cavalry/zimaboard-2-home-lab/discussions)
- 🤝 **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)

---

*This changelog is automatically updated with each release.*