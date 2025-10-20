#!/bin/bash
# ZimaBoard 2 Homelab Uninstall Script
# Removes all homelab services, configs, users, and data

set -e

echo "[INFO] Starting full homelab uninstall..."

# Stop and disable all services
systemctl stop nginx || true
systemctl disable nginx || true
systemctl stop pihole-FTL || true
systemctl disable pihole-FTL || true
systemctl stop squid || true
systemctl disable squid || true
systemctl stop netdata || true
systemctl disable netdata || true
systemctl stop wg-quick@wg0 || true
systemctl disable wg-quick@wg0 || true
systemctl stop mariadb || true
systemctl disable mariadb || true
systemctl stop redis-server || true
systemctl disable redis-server || true

# Remove packages
apt-get purge -y nginx nginx-common nginx-full nginx-core \
    pihole-ftl \
    squid \
    netdata \
    wireguard wireguard-tools \
    mariadb-server mariadb-client \
    redis-server \
    php* \
    fail2ban ufw \
    apache2 apache2-utils \
    unattended-upgrades \
    clamav clamav-daemon \
    nodejs npm \
    sqlite3 \
    curl wget git htop iotop dnsutils net-tools unzip parted
apt-get autoremove -y
apt-get clean

# Remove config and data directories
rm -rf /etc/nginx /var/www /etc/pihole /etc/squid /etc/netdata /etc/wireguard /etc/mysql /var/lib/mysql /var/lib/redis /var/lib/php /var/log/nginx /var/log/pihole /var/log/squid /var/log/netdata /var/log/wireguard /var/log/mysql /var/log/redis /var/log/php* /var/log/clamav /var/log/ufw /var/log/fail2ban
rm -rf /opt/homelab-data /mnt/ssd-data /mnt/ssd-backup /mnt/nextcloud-data /mnt/backup-storage

# Remove Nextcloud data if present
rm -rf /var/www/nextcloud /var/www/html/index.html

# Remove crontab for www-data
crontab -u www-data -r 2>/dev/null || true

# Remove firewall rules
ufw --force reset || true

# Remove fstab entries for SSD mounts
sed -i '/\/mnt\/ssd-data/d' /etc/fstab
sed -i '/\/mnt\/ssd-backup/d' /etc/fstab
sed -i '/\/mnt\/nextcloud-data/d' /etc/fstab
sed -i '/\/mnt\/backup-storage/d' /etc/fstab

# Remove sysctl optimizations
sed -i '/vm.swappiness/d' /etc/sysctl.conf
sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf

# Restore /var/log if it was symlinked
if [ -L /var/log ]; then
  rm /var/log
  mv /var/log.old /var/log 2>/dev/null || mkdir /var/log
fi

# Remove any remaining homelab scripts
rm -rf /opt/homelab /opt/homelab/scripts

echo "[SUCCESS] Homelab services and data removed."
echo "[INFO] Please review /etc/fstab, /etc/sysctl.conf, and /etc for any custom changes if you encounter issues."
echo "[INFO] A reboot is recommended to fully clear all mounts and services."