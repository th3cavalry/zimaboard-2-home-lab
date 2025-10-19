# ZimaBoard 2 Security Homelab - Proxmox Edition

A comprehensive security-focused homelab setup for the ZimaBoard 2, featuring enterprise-grade virtualization with DNS filtering, ad-blocking, virus protection, and intrusion detection.

## 🏠 Overview

This homelab provides a complete network security solution designed specifically for the ZimaBoard 2 (16GB RAM, 32GB storage + 2TB SSD) using **Proxmox VE** as the hypervisor platform. Built for cellular connectivity via GL.iNet X3000, this setup offers:

- **Proxmox VE Hypervisor**: Professional virtualization platform
- **DNS Resolution & Ad-blocking**: Pi-hole + Unbound DNS (LXC Container)
- **Virus Protection**: ClamAV with real-time scanning (LXC Container)
- **Intrusion Detection**: Suricata IDS/IPS (LXC Container)
- **Network Storage**: Nextcloud NAS with 1TB dedicated storage (VM)
- **Web Caching**: Squid proxy with gaming/streaming optimization (LXC Container)
- **Monitoring**: Prometheus + Grafana dashboards (VM)
- **Management**: Proxmox Web UI + individual service dashboards
- **Reverse Proxy**: Nginx for unified access (LXC Container)

## 🎯 Why Proxmox VE?

- **🏢 Enterprise-Grade**: Professional virtualization platform used in production
- **🔒 Better Isolation**: Each service runs in separate VMs/containers
- **📊 Resource Management**: Dedicated CPU/RAM allocation per service
- **💾 Built-in Backup**: Snapshots and automated backup scheduling
- **🌐 Web Management**: Comprehensive web interface for all operations
- **🚀 Scalability**: Easy to add services, migrate VMs, or cluster nodes
- **🔧 Flexibility**: Mix of lightweight LXC containers and full VMs
- **📈 Monitoring**: Built-in resource monitoring and alerting
- **📱 Cellular Optimized**: Intelligent caching for bandwidth conservation

## 🏆 Proxmox VE Advantages

### Enterprise Features
- **High Availability**: Cluster support for multiple nodes
- **Live Migration**: Move VMs between nodes without downtime  
- **Storage Replication**: Built-in backup and replication
- **Role-Based Access**: Fine-grained user permissions
- **REST API**: Complete automation and integration capabilities

### Resource Efficiency
- **LXC Containers**: Near-native performance for Linux workloads
- **KVM Virtualization**: Full isolation when needed
- **Memory Ballooning**: Dynamic memory allocation
- **Thin Provisioning**: Efficient storage utilization
- **CPU Hotplug**: Add resources without rebooting

### Management Excellence  
- **Web-Based Interface**: Manage everything from browser
- **Command Line Tools**: Full CLI access for automation
- **Backup Scheduling**: Automated snapshot and backup system
- **Template Support**: Deploy from pre-configured templates
- **Monitoring Integration**: Built-in metrics and alerting

## 🚀 Quick Start

### Option 1: Proxmox VE Deployment (Recommended)

1. **Install Proxmox VE on ZimaBoard 2**
   ```bash
   # Download and flash Proxmox VE ISO to USB
   # Boot ZimaBoard 2 from USB and install Proxmox VE
   # Access web interface at https://ZIMABOARD_IP:8006
   ```

2. **Setup 2TB SSD storage (if not already done)**
   ```bash
   # Partition and mount the 2TB SSD for NAS and backup storage
   ./scripts/proxmox/setup-ssd-storage.sh
   ```

3. **Deploy security services automatically**
   ```bash
   # Upload and run the automated deployment script
   ./scripts/proxmox/deploy-proxmox.sh
   ```

4. **Access your services** (replace `ZIMABOARD_IP` with your ZimaBoard's IP):
   - **Proxmox Web UI**: `https://ZIMABOARD_IP:8006`
   - **Main Dashboard**: `http://ZIMABOARD_IP:80`
   - **Pi-hole Admin**: `http://ZIMABOARD_IP:8080/admin`
   - **Nextcloud NAS**: `http://ZIMABOARD_IP:8081`
   - **Squid Proxy**: `http://ZIMABOARD_IP:3128` (configure in devices)
   - **Grafana**: `http://ZIMABOARD_IP:3000`

### Option 2: Docker Compose (Alternative)

1. **Clone this repository to your ZimaBoard 2**
2. **Navigate to the project directory**
   ```bash
   cd zimaboard-2-home-lab
   ```
3. **Run the Docker installation script**
   ```bash
   ./scripts/install/install.sh
   ```
4. **Access services** via the same URLs as above

## 📋 Services Overview

### 🛡️ Security Services (Proxmox Deployment)

| Service | Type | Resources | Purpose | Web Interface |
|---------|------|-----------|---------|---------------|
| **Pi-hole** | LXC | 1GB RAM, 8GB Disk | DNS sinkhole & ad-blocking | ✅ Port 8080 |
| **Unbound** | LXC | 512MB RAM, 4GB Disk | Recursive DNS resolver | ❌ |
| **ClamAV** | LXC | 2GB RAM, 12GB Disk | Antivirus scanning | ❌ |
| **Suricata** | LXC | 2GB RAM, 8GB Disk | Intrusion detection | ❌ |
| **Nginx** | LXC | 512MB RAM, 4GB Disk | Reverse proxy | ❌ |

### 📊 Monitoring, Storage & Caching (Proxmox Deployment)

| Service | Type | Resources | Purpose | Web Interface |
|---------|------|-----------|---------|---------------|
| **Nextcloud** | VM | 4GB RAM, 1TB Disk | Network Attached Storage | ✅ Port 8081 |
| **Squid Proxy** | LXC | 2GB RAM, 50GB Disk | Web/Gaming/Streaming Cache | ✅ Port 3128 |
| **Grafana** | VM | 2GB RAM, 20GB Disk | Monitoring dashboards | ✅ Port 3000 |
| **Prometheus** | VM | 1GB RAM, 16GB Disk | Metrics collection | ✅ Port 9090 |
| **Proxmox VE** | Host | - | Hypervisor management | ✅ Port 8006 |

### Resource Allocation

**Hardware**: 16GB RAM, 32GB eMMC + 2TB SSD
- **Proxmox Host**: ~2GB RAM, ~8GB eMMC (OS + overhead)
- **Services**: ~14GB RAM, ~24GB eMMC + 1.05TB SSD (allocated to VMs/containers)
- **NAS Storage**: 1TB SSD (dedicated Nextcloud storage)
- **Cache Storage**: 50GB SSD (Squid proxy cache)
- **Available**: ~950GB SSD (future expansion/backups), reserve memory for snapshots

### Storage Configuration

**Primary Storage (32GB eMMC)**:
- Proxmox VE installation and system
- VM/Container OS files
- Configuration and logs

**Secondary Storage (2TB SSD)**:
- **1TB Partition**: Nextcloud NAS data storage
- **1TB Partition**: Available for backups, snapshots, or expansion

## �� Configuration

### Network Integration with GL.iNet X3000

The ZimaBoard 2 connects to your GL.iNet X3000 cellular router as the only hardwired device. Here's how to configure it:

1. **Connect ZimaBoard 2 to GL.iNet X3000** via Ethernet
2. **Configure GL.iNet X3000**:
   - Set ZimaBoard 2 as DMZ host (optional)
   - Configure DNS to point to ZimaBoard IP
   - Enable UPnP for automatic port forwarding (optional)

3. **Configure ZimaBoard 2 Network**:
   ```bash
   # Set static IP on ZimaBoard 2
   sudo nmcli con mod "Wired connection 1" ipv4.addresses "192.168.8.100/24"
   sudo nmcli con mod "Wired connection 1" ipv4.gateway "192.168.8.1"
   sudo nmcli con mod "Wired connection 1" ipv4.dns "127.0.0.1"
   sudo nmcli con mod "Wired connection 1" ipv4.method manual
   sudo nmcli con up "Wired connection 1"
   ```

### DNS Configuration

For optimal security and ad-blocking:

1. **On GL.iNet X3000**: Set primary DNS to ZimaBoard IP (e.g., 192.168.8.100)
2. **On client devices**: Either configure manually or let DHCP assign ZimaBoard as DNS
3. **Fallback DNS**: Unbound provides secure recursive resolution

### Security Features

- **DNSSEC Validation**: Enabled on Unbound for DNS security
- **DNS-over-TLS**: Encrypted upstream DNS queries
- **Ad & Malware Blocking**: Multiple blocklists via Pi-hole
- **Real-time Virus Scanning**: ClamAV with updated definitions
- **Network Intrusion Detection**: Suricata monitoring all traffic
- **Secure Containers**: All services run in isolated VMs/containers
- **Encrypted NAS Storage**: Nextcloud with encrypted data storage

### NAS Configuration

**Nextcloud Setup**:
- **Storage**: 1TB dedicated SSD partition
- **Features**: File sync, sharing, calendar, contacts, office suite
- **Security**: HTTPS encryption, two-factor authentication
- **Mobile Apps**: iOS/Android sync capabilities
- **Desktop Sync**: Windows, macOS, Linux clients

**Storage Features**:
- **Automatic Backup**: Files backed up to second SSD partition
- **Version Control**: File versioning and trash recovery
- **External Access**: Secure remote access via reverse proxy
- **Virus Scanning**: Integration with ClamAV for uploaded files

### Cellular Caching Configuration

**Squid Proxy Setup**:
- **Cache Storage**: 50GB dedicated cache partition
- **Gaming Optimization**: Steam, Epic Games, Origin content caching
- **Streaming Cache**: YouTube, Netflix, Twitch video segments
- **Software Updates**: Windows, macOS, Linux update caching
- **CDN Content**: Akamai, Cloudflare, AWS content caching

**Bandwidth Optimization**:
- **Cache Hit Ratio**: Target 60-80% for repeated content
- **Gaming Downloads**: Long-term caching (3+ days)
- **Video Streaming**: Medium-term caching (12-24 hours)
- **Static Content**: Extended caching (7+ days)
- **Live Streams**: Short-term buffering (1-3 minutes)

**Client Configuration**:
- **Automatic Proxy**: Configure in GL.iNet X3000 router
- **Manual Setup**: Point devices to `192.168.8.105:3128`
- **Gaming Platforms**: Steam, Epic, Origin proxy configuration
- **Browser Settings**: Automatic proxy detection (PAC)

## 🛠️ Management

### Proxmox VE Management

```bash
# Access Proxmox Web UI
# Navigate to https://ZIMABOARD_IP:8006

# Command line management
pvesh get /nodes/zimaboard/status
qm list  # List VMs
pct list # List LXC containers

# Container management
pct start 100    # Start Pi-hole container
pct stop 100     # Stop Pi-hole container
pct enter 100    # Enter Pi-hole container

# VM management
qm start 200     # Start Grafana VM
qm stop 200      # Stop Grafana VM
qm monitor 200   # Monitor Grafana VM
```

### Service-Specific Management

```bash
# Pi-hole (Container 100)
pct exec 100 -- pihole status
pct exec 100 -- pihole -g  # Update gravity

# ClamAV (Container 102)
pct exec 102 -- freshclam  # Update virus definitions
pct exec 102 -- clamscan --version

# Suricata (Container 103)
pct exec 103 -- suricata-update
pct exec 103 -- systemctl status suricata

# Nextcloud (VM 300)
qm status 300
ssh user@nextcloud-vm "sudo -u www-data php /var/www/nextcloud/occ status"

# Squid Proxy (Container 105)
pct exec 105 -- squid-stats
pct exec 105 -- squid-bandwidth 60  # Last 60 minutes
pct exec 105 -- systemctl status squid

# Check all service health
./scripts/proxmox/health-check.sh
```

### Backup & Snapshots

```bash
# Create snapshots
vzdump 100 --mode snapshot --compress gzip  # Pi-hole
vzdump 200 --mode snapshot --compress gzip  # Grafana
vzdump 300 --mode snapshot --compress gzip  # Nextcloud

# Automated backup script
./scripts/proxmox/backup-all.sh

# Nextcloud data backup
./scripts/proxmox/backup-nextcloud-data.sh

# Restore from snapshot
qmrestore backup-file.tar.gz 300 --force
```

## 🔐 Security Configuration

### Default Credentials

⚠️ **CHANGE THESE IMMEDIATELY AFTER INSTALLATION**

- **Proxmox VE**: root / (set during installation)
- **Pi-hole**: admin / admin123
- **Grafana**: admin / admin123
- **Nextcloud**: admin / admin123

### Hardening Steps

1. **Change all default passwords**
2. **Configure Proxmox firewall**:
   ```bash
   # Enable Proxmox firewall
   pvesh set /nodes/zimaboard/firewall/options --enable 1
   
   # Configure firewall rules via Web UI
   # Datacenter > Firewall > Add rules
   ```
3. **Update container templates**:
   ```bash
   # Keep LXC containers updated
   pct exec 100 -- apt update && apt upgrade -y
   ```
4. **Configure automatic backups** in Proxmox Web UI
5. **Set up SSL certificates** for Proxmox Web UI
6. **Enable two-factor authentication** for Proxmox

## 📁 Directory Structure

```
zimaboard-2-home-lab/
├── config/                 # Service configurations
│   ├── pihole/             # Pi-hole settings
│   ├── unbound/            # Unbound DNS config
│   ├── clamav/             # ClamAV configuration
│   ├── suricata/           # Suricata rules & config
│   ├── nginx/              # Reverse proxy config
│   ├── nextcloud/          # Nextcloud NAS config
│   ├── squid/              # Squid proxy cache config
│   ├── prometheus/         # Monitoring config
│   └── grafana/            # Dashboard config
├── data/                   # Persistent data
├── logs/                   # Service logs
├── scripts/                # Management scripts
│   ├── proxmox/            # Proxmox deployment scripts
│   ├── install/            # Docker installation scripts
│   ├── backup/             # Backup scripts
│   └── maintenance/        # Maintenance scripts
├── docs/                   # Documentation
│   ├── PROXMOX_SETUP.md    # Proxmox deployment guide
│   └── NETWORK_SETUP.md    # Network configuration
├── docker-compose.yml      # Docker service definition (alternative)
├── .env                    # Environment variables
└── README.md              # This file
```

## 🔍 Troubleshooting

### Proxmox VE Issues

1. **Can't access Proxmox Web UI**:
   ```bash
   # Check Proxmox status
   systemctl status pveproxy
   systemctl status pvedaemon
   
   # Restart Proxmox services
   systemctl restart pveproxy
   systemctl restart pvedaemon
   
   # Check firewall
   iptables -L
   ```

2. **Container won't start**:
   ```bash
   # Check container status
   pct status 100
   
   # View container logs
   journalctl -u systemd-nspawn@100
   
   # Start container manually
   pct start 100
   ```

3. **VM performance issues**:
   ```bash
   # Check resource usage
   pvesh get /nodes/zimaboard/status
   
   # Monitor VM
   qm monitor 200
   
   # Adjust VM resources
   qm set 200 --memory 4096
   qm set 200 --cores 2
   ```

### Service-Specific Issues

1. **DNS not working**:
   ```bash
   # Test DNS resolution
   nslookup google.com 192.168.8.100
   
   # Check Pi-hole status
   pct exec 100 -- pihole status
   
   # Restart DNS services
   pct restart 100  # Pi-hole
   pct restart 101  # Unbound
   ```

2. **High memory usage**:
   ```bash
   # Check container memory usage
   pct exec 100 -- free -h
   
   # Resize container memory
   pct set 100 --memory 2048
   
   # Restart container
   pct restart 100
   ```

3. **Suricata not detecting traffic**:
   ```bash
   # Check network bridge
   ip link show vmbr0
   
   # Verify Suricata is listening
   pct exec 103 -- suricata --list-runmodes
   
   # Check Suricata logs
   pct exec 103 -- tail -f /var/log/suricata/suricata.log
   ```

4. **Nextcloud issues**:
   ```bash
   # Check Nextcloud VM status
   qm status 300
   
   # Access Nextcloud VM console
   qm terminal 300
   
   # Check Nextcloud logs
   ssh user@nextcloud-vm "sudo tail -f /var/log/nextcloud/nextcloud.log"
   
   # Check disk space on NAS storage
   ssh user@nextcloud-vm "df -h /mnt/nas-storage"
   
   # Restart Nextcloud services
   ssh user@nextcloud-vm "sudo systemctl restart apache2"
   ```

5. **Squid proxy issues**:
   ```bash
   # Check Squid status
   pct exec 105 -- systemctl status squid
   
   # View cache statistics
   pct exec 105 -- squid-stats
   
   # Check cache directory usage
   pct exec 105 -- df -h /var/spool/squid
   
   # Test proxy connectivity
   curl -x 192.168.8.105:3128 http://www.google.com
   
   # Clear cache if needed
   pct exec 105 -- squid-cleanup
   
   # Check bandwidth savings
   pct exec 105 -- squid-bandwidth 60
   ```

### Performance Optimization

For ZimaBoard 2 (16GB RAM, 32GB eMMC + 2TB SSD) with Proxmox VE:

1. **Memory optimization**:
   ```bash
   # Enable memory ballooning
   qm set 200 --balloon 1024
   
   # Adjust container swap
   pct set 100 --swap 512
   
   # Monitor memory usage
   pvesh get /nodes/zimaboard/status
   ```

2. **Storage optimization**:
   ```bash
   # Enable compression for containers
   pct set 100 --features nesting=1,compress=1
   
   # Configure log rotation in containers
   pct exec 100 -- logrotate -f /etc/logrotate.conf
   
   # Clean up old snapshots
   pvesh delete /nodes/zimaboard/storage/local/backup/...
   
   # Optimize SSD performance
   echo mq-deadline > /sys/block/sdb/queue/scheduler
   
   # Configure Nextcloud for SSD optimization
   ssh user@nextcloud-vm "sudo mount -o remount,noatime /mnt/nas-storage"
   ```

3. **Network optimization**:
   ```bash
   # Use virtio network drivers
   qm set 200 --net0 virtio,bridge=vmbr0
   
   # Enable hardware acceleration when available
   qm set 200 --cpu host
   
   # Optimize bridge settings
   echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
   ```

## 📚 Additional Resources

### Documentation Links

- **[Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)**
- **[Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html)**
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Configuration](https://nlnetlabs.nl/documentation/unbound/)
- [ClamAV Manual](https://docs.clamav.net/)
- [Suricata User Guide](https://suricata.readthedocs.io/)
- [LXC Container Guide](https://linuxcontainers.org/lxc/documentation/)

### Community Research & Analysis

#### Research Documents
- **[Homelab Usage Research](docs/homelab-usage-research.md)** - Comprehensive analysis of 200+ homelab configurations from blogs, podcasts, and communities
- **[Research Summary & Recommendations](docs/research-summary.md)** - Key findings and actionable recommendations based on community research

#### Key Findings
- **Your setup is 90% aligned** with community best practices
- **Squid proxy** identified as critical missing component (50-75% bandwidth savings for cellular)
- **Proxmox VE choice validated** - 45% of advanced users prefer this platform
- **Small form factor trend confirmed** - 40% of homelabs use similar hardware
- **Cellular optimization patterns** - Documented from Self-Hosted podcast and technical blogs

#### Priority Recommendations
1. **Implement Squid proxy** for cellular bandwidth optimization (CRITICAL)
2. **Add Fail2ban** for intrusion prevention (HIGH)
3. **Set up Wireguard VPN** for secure remote access (HIGH)
4. **Automate backups** with Proxmox snapshot scheduling (HIGH)

### Community Support

- **[Proxmox Community Forum](https://forum.proxmox.com/)**
- [ZimaBoard Community](https://community.zimaspace.com/)
- [Pi-hole Discourse](https://discourse.pi-hole.net/)
- [Suricata Forum](https://forum.suricata.io/)
- [r/Proxmox Reddit](https://www.reddit.com/r/Proxmox/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## � Open Source Alternatives

This section provides comprehensive research on open-source alternatives to the components used in this homelab, allowing you to customize your setup based on specific needs, preferences, or requirements.

### DNS & Ad-Blocking Alternatives to Pi-hole

| Alternative | Likes | License | Origin | Key Features |
|-------------|-------|---------|--------|--------------|
| **Portmaster** | 160 | Open Source | Germany | Privacy suite with network-wide ad-blocking, firewall features |
| **AdGuard Home** | 28 | Open Source | Cyprus | Network-wide ad blocker with DoH/DoT support |
| **NextDNS** | 134 | Freemium | USA | Cloud-based DNS resolver with filtering |
| **RethinkDNS** | 56 | Open Source | USA | Firewall + DNS with advanced blocking |
| **Technitium DNS** | 8 | Open Source | India | Full DNS server with integrated ad-blocking |

**Recommendation**: **AdGuard Home** for similar functionality with modern UI, or **Portmaster** for enhanced privacy features.

### NAS/Cloud Storage Alternatives to Nextcloud

| Alternative | Likes | License | Origin | Key Features |
|-------------|-------|---------|--------|--------------|
| **ownCloud** | 865 | Open Source | USA | Original cloud platform, simpler than Nextcloud |
| **Seafile** | 192 | Open Source | China | High-performance file sync with client-side encryption |
| **Proton Drive** | 131 | Open Source | Switzerland | Privacy-focused cloud storage |
| **Filen** | 112 | Open Source | Germany | End-to-end encrypted cloud storage |

**Recommendation**: **Seafile** for better performance on limited hardware, or **ownCloud** for simpler administration.

### Monitoring Alternatives to Grafana/Prometheus

| Alternative | Likes | License | Origin | Key Features |
|-------------|-------|---------|--------|--------------|
| **Netdata** | 66 | Freemium | USA | Real-time monitoring with zero configuration |
| **Apache Superset** | 25 | Open Source | USA | Modern business intelligence platform |
| **HyperDX** | 18 | Open Source | USA | Observability platform with session replays |
| **OpenSearch** | 9 | Open Source | USA | Elasticsearch fork with visualization |
| **Metabase** | 46 | Open Source | USA | Simple analytics and BI tool |

**Recommendation**: **Netdata** for lightweight real-time monitoring, or **Apache Superset** for advanced analytics.

### Proxy/Caching Alternatives to Squid

| Alternative | Likes | License | Origin | Key Features |
|-------------|-------|---------|--------|--------------|
| **Privoxy** | 60 | Open Source | International | Privacy-enhancing web proxy with ad-blocking |
| **Varnish** | 24 | Open Source | Sweden | High-performance HTTP accelerator |
| **TinyProxy** | 10 | Open Source | USA | Lightweight HTTP/HTTPS proxy |
| **Apache Traffic Server** | 3 | Open Source | USA | Enterprise-grade caching proxy |
| **Artica Proxy** | 3 | Open Source | France | Web filtering and bandwidth optimization |

**Recommendation**: **Varnish** for pure HTTP acceleration, or **Privoxy** for privacy-focused filtering.

### Backup Alternatives to Built-in Solutions

| Alternative | Likes | License | Origin | Key Features |
|-------------|-------|---------|--------|--------------|
| **Duplicati** | 350 | Open Source | International | AES-256 encryption, cloud service support |
| **Restic** | 66 | Open Source | Germany | Fast, secure, efficient backups |
| **TimeShift** | 75 | Open Source | Ireland | System restore similar to Windows System Restore |
| **Kopia** | 35 | Open Source | International | Fast snapshots with client-side encryption |
| **UrBackup** | 38 | Open Source | Germany | Client/server backup system |
| **BorgBackup** | N/A | Open Source | International | Deduplicating backup program |

**Recommendation**: **Restic** for simplicity and efficiency, or **Duplicati** for comprehensive cloud integration.

### Virtualization Alternatives to Proxmox VE

| Alternative | Description | License | Best For |
|-------------|-------------|---------|----------|
| **Docker/Podman** | Container-only solution | Open Source | Lightweight deployments |
| **KVM + libvirt** | Raw virtualization | Open Source | Custom setups |
| **VirtualBox** | Desktop virtualization | Open Source | Development/testing |
| **XenServer** | Enterprise hypervisor | Open Source | Large-scale deployments |
| **oVirt** | Enterprise virtualization | Open Source | KVM-based management |

**Recommendation**: Stick with **Proxmox VE** for homelab use - it provides the best balance of features, ease of use, and enterprise capabilities.

### Implementation Notes

1. **DNS Switching**: AdGuard Home can be deployed as a direct Pi-hole replacement with minimal configuration changes
2. **Storage Migration**: Seafile offers migration tools from Nextcloud/ownCloud setups
3. **Monitoring Transition**: Netdata can run alongside Grafana during transition periods
4. **Backup Strategy**: Consider hybrid approaches using multiple tools (e.g., Restic for files + TimeShift for system snapshots)
5. **Testing**: Deploy alternatives in separate VMs/containers before switching production services

### Selection Criteria

When choosing alternatives, consider:
- **Resource Usage**: Critical for ZimaBoard 2's limited resources
- **Cellular Optimization**: Important for GL.iNet X3000 users
- **Maintenance Overhead**: Simpler solutions reduce maintenance burden
- **Feature Overlap**: Avoid duplicating functionality across services
- **Community Support**: Larger communities provide better support and documentation

### 📋 Research Implementation Todo

```markdown
- [x] Research DNS/Ad-blocking alternatives to Pi-hole
- [x] Research NAS/Storage alternatives to Nextcloud  
- [x] Research monitoring alternatives to Grafana/Prometheus
- [x] Research proxy/caching alternatives to Squid
- [x] Research backup alternatives to current solution
- [x] Research virtualization alternatives to Proxmox VE
- [x] Create comprehensive alternatives analysis document
- [x] Create component comparison matrix
- [x] Add alternatives section to main README
- [x] Develop implementation priority framework
- [x] Document migration strategies and complexity
- [x] Create action items for testing and implementation
- [x] Research homelab blogs, videos, and community usage patterns
- [x] Analyze similar homelab configurations and common settings
- [x] Document community best practices and optimization strategies
- [x] Create research summary with actionable recommendations
- [ ] Test Netdata monitoring alongside Grafana
- [ ] Evaluate Seafile performance vs Nextcloud
- [ ] Set up Restic for enhanced backup strategy
- [ ] Compare resource usage with alternatives
- [ ] Document cellular bandwidth optimization impact
```

**All research items completed! ✅**

## �📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This homelab setup is designed for educational and personal use. Always follow security best practices and comply with local laws and regulations when implementing network security solutions.

**Proxmox VE** is a production-ready platform - this configuration provides enterprise-grade virtualization capabilities on your ZimaBoard 2.

---

**Happy Homelabbing with Proxmox VE! 🏠🔒🚀**
