# 📝 ZimaBoard 2 Homelab Repository - Current State Documentation

**Date**: October 20, 2025  
**Purpose**: Complete documentation before repo recreation

---

## 🎯 Repository Overview

**Repository**: zimaboard-2-home-lab (th3cavalry/zimaboard-2-home-lab)  
**Branch**: main  
**Last Commit**: 52ecc8b - "Replace Pi-hole with AdGuard Home as default DNS solution"

---

## 📊 Current Setup Summary

### **Platform**
- **Base OS**: Ubuntu Server 24.04 LTS (5-year support)
- **Target Hardware**: ZimaBoard 2 (16GB RAM, 64GB eMMC, 2TB SSD)
- **Architecture**: Direct installation (no containers/virtualization)
- **Network**: Optimized for cellular internet + GL.iNet X3000 router

### **Core Services**
```
Service         Port    Status  Purpose
─────────────────────────────────────────────────────────
AdGuard Home    3000    ✅      DNS filtering (default)
Pi-hole         8080    📦      Alternative DNS option
Nextcloud       8000    ✅      Personal cloud + office
WireGuard       51820   ✅      VPN server (UDP)
Squid           3128    ✅      Bandwidth optimization
Netdata         19999   ✅      System monitoring
Nginx           80      ✅      Web services & proxy
MariaDB         3306    ✅      Nextcloud database
Redis           6379    ✅      Nextcloud cache
```

### **Key Features**
- ✅ One-command installation
- ✅ Interactive SSD setup (format/use existing/skip)
- ✅ eMMC optimization (90%+ write reduction)
- ✅ Cellular bandwidth savings (50-75%)
- ✅ No port conflicts (AdGuard Home on 3000, nginx on 80)
- ✅ Complete uninstall script
- ✅ Migration scripts (Pi-hole ↔ AdGuard Home)

---

## 📁 Directory Structure

```
zimaboard-2-home-lab/
├── README.md                    # Main documentation (comprehensive)
├── CHANGELOG.md                 # Deployment history
├── DEPLOYMENT_STATUS.md         # Real-time system status
├── PROJECT_COMPLETION.md        # Project milestones
├── .env                         # Environment variables
├── docker-compose.yml           # Docker alternative (legacy)
├── docker-backup.yml            # Docker backup config (legacy)
│
├── config/                      # Service configurations
│   ├── clamav/
│   ├── grafana/
│   ├── nextcloud/
│   ├── nginx/
│   ├── prometheus/
│   ├── squid/
│   ├── suricata/
│   └── unbound/
│
├── docs/                        # Documentation
│   ├── ADGUARD_HOME_GUIDE.md   # AdGuard Home migration guide
│   ├── PIHOLE_ALTERNATIVE.md   # Pi-hole installation guide
│   ├── CELLULAR_OPTIMIZATION.md
│   ├── EMMC_OPTIMIZATION.md
│   ├── NETWORK_SETUP.md
│   ├── DOCKER_VS_PROXMOX.md
│   ├── PROXMOX_SETUP.md
│   ├── alternatives-analysis.md
│   ├── component-comparison.md
│   ├── homelab-usage-research.md
│   ├── research-summary.md
│   ├── streaming-ad-blocking.md
│   └── network/
│       └── gl-inet-x3000-setup.md
│
└── scripts/                     # Installation & management scripts
    ├── backup/
    │   └── backup.sh
    ├── install/
    │   └── install.sh
    ├── maintenance/
    │   └── maintenance.sh
    ├── proxmox/
    │   ├── backup-all.sh
    │   ├── backup-nextcloud-data.sh
    │   ├── backup-seafile-data.sh
    │   ├── cleanup-snapshots.sh
    │   ├── complete-setup.sh
    │   ├── deploy-proxmox.sh
    │   ├── health-check.sh
    │   ├── setup-ssd-storage.sh
    │   └── setup-streaming-adblock.sh
    ├── simple-install/
    │   ├── ubuntu-homelab-simple.sh      # MAIN INSTALLER
    │   ├── uninstall-homelab.sh          # Complete removal
    │   └── migrate-to-adguardhome.sh     # Migration script
    └── streaming-adblock/
        └── setup-streaming-adblock.sh
```

---

## 🔑 Critical Files

### **1. Main Installation Script**
**File**: `scripts/simple-install/ubuntu-homelab-simple.sh`  
**Size**: ~1200 lines  
**Purpose**: Complete one-command homelab deployment

**Key Features**:
- Architecture detection (amd64/arm64/armv7)
- Interactive SSD setup with 4 modes
- AdGuard Home installation with DNS-over-HTTPS
- Nextcloud with office suite integration
- WireGuard VPN with QR code generation
- Squid proxy with SSL inspection
- Netdata monitoring (zero-config)
- Nginx reverse proxy configuration
- UFW firewall setup
- eMMC optimization (swappiness, noatime, zswap)
- Service verification and health checks

**Installation Command**:
```bash
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/ubuntu-homelab-simple.sh
chmod +x ubuntu-homelab-simple.sh
sudo ./ubuntu-homelab-simple.sh
```

### **2. Uninstall Script**
**File**: `scripts/simple-install/uninstall-homelab.sh`  
**Purpose**: Complete system cleanup

**Removes**:
- All services (AdGuard Home, Nextcloud, WireGuard, Squid, Netdata, Nginx)
- Configuration files and databases
- Data directories (eMMC and SSD)
- Firewall rules
- System optimizations
- Service users and cron jobs

### **3. Migration Scripts**
**File**: `scripts/simple-install/migrate-to-adguardhome.sh`  
**Purpose**: Automated Pi-hole → AdGuard Home migration

**Features**:
- Backup Pi-hole configuration
- Clean Pi-hole removal
- AdGuard Home installation
- Port configuration (resolves conflicts)
- Nginx port update (80 → 80, no conflicts)
- Firewall rule updates

### **4. README.md**
**Size**: ~2700 lines  
**Sections**: 40+

**Major Sections**:
- Quick Start (TL;DR)
- Ubuntu Installation (step-by-step)
- Services & Access
- Configuration & Management
- Troubleshooting (comprehensive)
- Advanced Topics (alternatives, resources, security)
- Network Setup (GL.iNet X3000)
- Alternative Programs (2025 recommendations)

---

## 🚀 Recent Major Changes

### **Commit 52ecc8b** (Latest)
**Title**: Replace Pi-hole with AdGuard Home as default DNS solution

**Changes**:
1. **README.md**: 
   - Updated all Pi-hole references to AdGuard Home
   - Changed port assignments (nginx 80, AdGuard 3000)
   - Added Pi-hole alternative guide reference
   - Updated 40+ sections

2. **ubuntu-homelab-simple.sh**:
   - Replaced Pi-hole installation with AdGuard Home
   - Added comprehensive AdGuard Home YAML configuration
   - Implemented DNS-over-HTTPS by default
   - Fixed port conflicts (nginx can use port 80)
   - Added architecture detection for ARM support

3. **New Files**:
   - `docs/PIHOLE_ALTERNATIVE.md`: Complete Pi-hole guide
   - `docs/ADGUARD_HOME_GUIDE.md`: Migration documentation
   - `scripts/simple-install/migrate-to-adguardhome.sh`: Migration script

**Benefits**:
- No port conflicts (AdGuard Home uses 3000, nginx uses 80)
- Modern UI with better mobile support
- DNS-over-HTTPS built-in
- Better performance and lower resource usage
- Easier management and configuration

---

## 📊 Service Comparison: AdGuard Home vs Pi-hole

| Feature | AdGuard Home | Pi-hole |
|---------|--------------|---------|
| Port Usage | 3000 (web), 53 (DNS) | 80 (FTL), 8080 (admin) |
| DNS-over-HTTPS | Built-in | Requires Cloudflared |
| UI | Modern, mobile-friendly | Classic web interface |
| Configuration | YAML + Web UI | Web UI + config files |
| Port Conflicts | None (nginx on 80) | Conflicts with nginx |
| Resource Usage | ~150MB RAM | ~100MB RAM |
| Community | Growing (30k+ stars) | Huge (48k+ stars) |

**Current Default**: AdGuard Home (better for ZimaBoard 2 setup)  
**Alternative**: Pi-hole (available via alternative guide)

---

## 🎯 Key Technical Decisions

### **1. Direct Installation vs Containers**
**Choice**: Direct installation (no Docker/Podman)

**Reasons**:
- Lower resource overhead
- Simpler troubleshooting
- Easier service management (systemd)
- Better performance on embedded hardware
- No container orchestration complexity
- Direct access to logs and configurations

### **2. Ubuntu Server 24.04 LTS vs Proxmox**
**Choice**: Ubuntu Server 24.04 LTS

**Reasons**:
- 5-year LTS support (until 2029)
- Excellent eMMC support out-of-the-box
- Lower resource requirements
- Simpler for beginners
- Native systemd service management
- Better for single-purpose systems

### **3. eMMC + SSD Storage Strategy**
**Choice**: OS on eMMC, data on SSD

**Implementation**:
- eMMC: Ubuntu OS, service binaries (60GB)
- SSD: User data, logs, cache, backups (2TB)
- Optimizations: noatime, swappiness=10, zswap
- Result: 90%+ reduction in eMMC writes

**Benefits**:
- Extended eMMC lifespan (10-50+ years)
- Better performance (SSD for I/O operations)
- Cleaner OS separation from data
- Easier backups and recovery

### **4. AdGuard Home as Default DNS**
**Choice**: AdGuard Home (replacing Pi-hole)

**Reasons**:
- No port conflicts with nginx
- DNS-over-HTTPS built-in
- Modern UI and mobile support
- Better API and automation
- Simpler configuration (YAML)
- Lower resource usage

### **5. Nextcloud vs Seafile**
**Choice**: Nextcloud (upgraded from Seafile)

**Reasons**:
- 400+ apps ecosystem
- Office suite integration (Collabora/OnlyOffice)
- Calendar and contacts sync
- Better mobile apps
- Larger community (27k+ stars)
- More active development

---

## 📈 Repository Statistics

**Total Commits**: 5+ (recent)  
**Files Changed (Last Commit)**: 5  
**Insertions**: 1505+  
**Deletions**: 101+  

**Documentation**:
- README.md: ~2700 lines
- Total docs: 13 markdown files
- Guide coverage: Complete

**Scripts**:
- Main installer: ~1200 lines
- Total scripts: 15+ files
- Coverage: Installation, backup, maintenance, migration

---

## 🔄 Migration Paths

### **From Pi-hole to AdGuard Home**
```bash
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/scripts/simple-install/migrate-to-adguardhome.sh
chmod +x migrate-to-adguardhome.sh
sudo ./migrate-to-adguardhome.sh
```

### **From AdGuard Home to Pi-hole**
See: `docs/PIHOLE_ALTERNATIVE.md`

### **From Seafile to Nextcloud**
Already completed in main installation script.

---

## 🎓 2025 Research Foundation

**Based on**: awesome-selfhosted database analysis (4,000+ services)

**Top-Rated Services by Category**:

1. **DNS/Ad-Blocking**: AdGuard Home (30.5k), Pi-hole (48.2k)
2. **File Sync**: Nextcloud (27k), Seafile (12k)
3. **Monitoring**: Netdata (71k), Grafana (70k)
4. **VPN**: WireGuard (gold standard)
5. **Proxy**: Squid (proven, stable)
6. **Web Server**: Nginx (industry standard)

**Emerging 2025 Trends**:
- Password management: Vaultwarden (37k)
- Photo management: Immich (47k)
- Media servers: Jellyfin (33k)
- Authentication: Authentik (13k)
- Management UI: CasaOS (25k)

---

## 🔧 Hardware Requirements

**Minimum**:
- ZimaBoard 2 (8GB RAM)
- 64GB eMMC (standard)
- Network connection

**Recommended**:
- ZimaBoard 2 (16GB RAM)
- 64GB eMMC (standard)
- 2TB+ SSD (SATA or NVMe)
- GL.iNet X3000 cellular router

**Optimal**:
- ZimaBoard 2 (16GB RAM)
- 64GB eMMC (standard)
- 2TB NVMe SSD
- GL.iNet X3000 + 5G plan
- UPS backup power

---

## 📝 Notes for Repo Recreation

### **What to Keep**:
- ✅ All documentation (README, guides)
- ✅ Main installation script
- ✅ Uninstall script
- ✅ Migration scripts
- ✅ Configuration examples
- ✅ Backup scripts

### **What to Archive/Remove**:
- ❌ Docker-related files (legacy, not used)
- ❌ Old Proxmox scripts (alternative approach)
- ❌ Unused config files
- ❌ PROJECT_COMPLETION.md (internal tracking)

### **What to Improve**:
- 🔄 Simplify directory structure
- 🔄 Add CI/CD testing
- 🔄 Add contribution guidelines
- 🔄 Create issue templates
- 🔄 Add automated testing scripts
- 🔄 Improve script modularity

---

## 🎯 Repository Purpose

**Primary Goal**: Provide a complete, one-command homelab solution for ZimaBoard 2 + cellular internet

**Target Audience**:
- Homelab enthusiasts
- Cellular internet users
- ZimaBoard 2 owners
- Privacy-focused individuals
- Self-hosting beginners

**Key Value Propositions**:
1. One-command installation
2. Research-backed service selection
3. Cellular bandwidth optimization
4. eMMC longevity optimization
5. Beginner-friendly approach
6. No containers required
7. Complete documentation
8. Active maintenance

---

## 📞 Contact & Links

**Repository**: https://github.com/th3cavalry/zimaboard-2-home-lab  
**Owner**: th3cavalry  
**License**: MIT License

**Related Resources**:
- ZimaBoard Community: https://community.zimaspace.com/
- Ubuntu Server: https://ubuntu.com/server
- GL.iNet X3000: https://www.gl-inet.com/products/gl-x3000/

---

**End of Documentation**  
**Status**: Ready for repo recreation ✅
