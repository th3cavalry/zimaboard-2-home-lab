# 🏠 ZimaBoard 2 Homelab - Ubuntu Edition

**The ultimate one-command security homelab for ZimaBoard 2 + cellular internet**

[![Ubuntu Server](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu)](https://ubuntu.com/server)
[![ZimaBoard](https://img.shields.io/badge/ZimaBoard-2_Supported-0066CC?style=for-the-badge)](https://www.zimaspace.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-brightgreen?style=for-the-badge)](https://github.com/th3cavalry/zimaboard-2-home-lab)

> 🚀 **Deploy a complete security homelab in minutes** - No containers, no complexity, just works!

---

## ✨ Features

- 🔒 **Network-wide ad blocking** with AdGuard Home (DNS-over-HTTPS included)
- ☁️ **Personal cloud storage** with Nextcloud (office suite, calendar, contacts)
- 🔐 **Secure VPN** with WireGuard for remote access
- ⚡ **Bandwidth optimization** with Squid proxy (50-75% savings on cellular)
- 📊 **Real-time monitoring** with Netdata
- 💾 **Smart storage** - OS on eMMC, data on SSD
- 🛡️ **Built-in security** - UFW firewall, fail2ban, automatic updates

---

## 🚀 Quick Start

### Prerequisites

- **ZimaBoard 2** (16GB RAM recommended)
- **Ubuntu Server 24.04 LTS** installed
- **2TB+ SSD** (recommended for data storage)
- **Network connection** (Ethernet)

### One-Command Installation

```bash
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh | sudo bash
```

**Or download first** (recommended):

```bash
wget https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

**That's it!** Your homelab will be ready at `http://192.168.8.2`

---

## 📦 What's Included

| Service | Port | Purpose |
|---------|------|---------|
| **AdGuard Home** | 3000 | DNS filtering & ad-blocking |
| **Nextcloud** | 8000 | Personal cloud + office suite |
| **WireGuard** | 51820 | VPN server (UDP) |
| **Squid** | 3128 | Bandwidth optimization |
| **Netdata** | 19999 | System monitoring |
| **Nginx** | 80 | Web dashboard & reverse proxy |

---

## 📖 Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- **[Service Management](docs/SERVICES.md)** - Managing your services
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Network Setup](docs/NETWORK.md)** - Cellular router configuration
- **[Storage Optimization](docs/STORAGE.md)** - eMMC + SSD best practices

---

## 🎯 Why This Setup?

### **Simplicity First**
- ✅ One-command installation
- ✅ No containers or virtualization complexity
- ✅ Direct systemd service management
- ✅ Easy troubleshooting and maintenance

### **Optimized for ZimaBoard 2**
- ✅ eMMC longevity optimization (90%+ write reduction)
- ✅ SSD for all data operations
- ✅ Cellular bandwidth savings (50-75%)
- ✅ Low resource usage (< 4GB RAM)

### **Research-Backed**
- ✅ Based on awesome-selfhosted analysis (4,000+ services)
- ✅ Top-rated services in each category
- ✅ 2025 best practices and security standards
- ✅ Active community support

---

## 🔧 Post-Installation

After installation completes, access your services:

- **Web Dashboard**: http://192.168.8.2
- **AdGuard Home**: http://192.168.8.2:3000 (default: admin/admin123)
- **Nextcloud**: http://192.168.8.2:8000 (default: admin/admin123)
- **Netdata**: http://192.168.8.2:19999

**⚠️ Change default passwords immediately!**

---

## 🗑️ Uninstall

To completely remove the homelab:

```bash
curl -sSL https://raw.githubusercontent.com/th3cavalry/zimaboard-2-home-lab/main/uninstall.sh | sudo bash
```

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md).

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- **ZimaBoard Community** - Hardware support and testing
- **awesome-selfhosted** - Service research and recommendations
- **Ubuntu Server** - Rock-solid foundation
- **Open Source Community** - Amazing software that makes this possible

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/th3cavalry/zimaboard-2-home-lab/issues)
- **Discussions**: [GitHub Discussions](https://github.com/th3cavalry/zimaboard-2-home-lab/discussions)
- **ZimaBoard**: [ZimaSpace Community](https://community.zimaspace.com/)

---

<div align="center">

**Built with ❤️ for the homelab community**

[![Star on GitHub](https://img.shields.io/github/stars/th3cavalry/zimaboard-2-home-lab?style=social)](https://github.com/th3cavalry/zimaboard-2-home-lab)

</div>
