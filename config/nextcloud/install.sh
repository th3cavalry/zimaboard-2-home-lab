#!/bin/bash

# Nextcloud Installation Script for Proxmox VM
# This script sets up Nextcloud with MySQL, Redis, and optimal configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nextcloud Installation Script ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt install -y apache2 mariadb-server php8.1 php8.1-fpm php8.1-mysql php8.1-xml php8.1-zip \
    php8.1-curl php8.1-gd php8.1-intl php8.1-mcrypt php8.1-imagick php8.1-mbstring \
    php8.1-bcmath php8.1-gmp php8.1-apcu php8.1-redis redis-server unzip wget curl

# Enable Apache modules
echo -e "${YELLOW}Enabling Apache modules...${NC}"
a2enmod rewrite headers env dir mime ssl proxy proxy_fcgi setenvif
a2enconf php8.1-fpm

# Download and install Nextcloud
echo -e "${YELLOW}Downloading Nextcloud...${NC}"
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2
mv nextcloud /var/www/
chown -R www-data:www-data /var/www/nextcloud
chmod -R 755 /var/www/nextcloud

# Create data directory
echo -e "${YELLOW}Setting up data directory...${NC}"
mkdir -p /mnt/nas-storage/data
chown www-data:www-data /mnt/nas-storage/data
chmod 750 /mnt/nas-storage/data

# Setup MySQL database
echo -e "${YELLOW}Setting up MySQL database...${NC}"
mysql -e "CREATE DATABASE nextcloud;"
mysql -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'secure_password_here';"
mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Configure Redis
echo -e "${YELLOW}Configuring Redis...${NC}"
systemctl enable redis-server
systemctl start redis-server

# Configure PHP
echo -e "${YELLOW}Configuring PHP...${NC}"
cat > /etc/php/8.1/fpm/conf.d/99-nextcloud.ini << 'EOPHP'
memory_limit = 1G
upload_max_filesize = 16G
post_max_size = 16G
max_execution_time = 3600
max_input_time = 3600
output_buffering = 0
opcache.enable = 1
opcache.memory_consumption = 128
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 1
opcache.save_comments = 1
apc.enable_cli = 1
EOPHP

# Restart services
echo -e "${YELLOW}Restarting services...${NC}"
systemctl restart php8.1-fpm
systemctl restart apache2

# Setup Apache virtual host
echo -e "${YELLOW}Setting up Apache virtual host...${NC}"
cp /tmp/apache.conf /etc/apache2/sites-available/nextcloud.conf
a2ensite nextcloud.conf
a2dissite 000-default.conf
systemctl reload apache2

# Install Nextcloud via command line
echo -e "${YELLOW}Installing Nextcloud...${NC}"
cd /var/www/nextcloud
sudo -u www-data php occ maintenance:install \
    --database "mysql" \
    --database-name "nextcloud" \
    --database-user "nextcloud" \
    --database-pass "secure_password_here" \
    --admin-user "admin" \
    --admin-pass "admin123" \
    --data-dir "/mnt/nas-storage/data"

# Configure trusted domains
echo -e "${YELLOW}Configuring trusted domains...${NC}"
sudo -u www-data php occ config:system:set trusted_domains 1 --value=192.168.8.100
sudo -u www-data php occ config:system:set trusted_domains 2 --value=10.0.0.100
sudo -u www-data php occ config:system:set trusted_domains 3 --value=nextcloud.local

# Configure caching
echo -e "${YELLOW}Configuring caching...${NC}"
sudo -u www-data php occ config:system:set memcache.local --value='\OC\Memcache\APCu'
sudo -u www-data php occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
sudo -u www-data php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'
sudo -u www-data php occ config:system:set redis host --value=localhost
sudo -u www-data php occ config:system:set redis port --value=6379

# Install recommended apps
echo -e "${YELLOW}Installing recommended apps...${NC}"
sudo -u www-data php occ app:enable files_external
sudo -u www-data php occ app:install calendar
sudo -u www-data php occ app:install contacts
sudo -u www-data php occ app:install mail
sudo -u www-data php occ app:install notes
sudo -u www-data php occ app:install tasks

# Setup cron job
echo -e "${YELLOW}Setting up cron job...${NC}"
crontab -u www-data -l 2>/dev/null | { cat; echo "*/5 * * * * php -f /var/www/nextcloud/cron.php"; } | crontab -u www-data -
sudo -u www-data php occ background:cron

# Create backup script
echo -e "${YELLOW}Creating backup script...${NC}"
cat > /usr/local/bin/nextcloud-backup << 'EOSCRIPT'
#!/bin/bash
BACKUP_DIR="/mnt/nas-storage/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Enable maintenance mode
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on

# Backup database
mysqldump nextcloud > $BACKUP_DIR/nextcloud_db_$DATE.sql

# Backup config and data
tar -czf $BACKUP_DIR/nextcloud_files_$DATE.tar.gz /var/www/nextcloud/config /mnt/nas-storage/data

# Disable maintenance mode
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off

# Clean old backups (keep 7 days)
find $BACKUP_DIR -name "nextcloud_*" -mtime +7 -delete

echo "Backup completed: $DATE"
EOSCRIPT

chmod +x /usr/local/bin/nextcloud-backup

# Add weekly backup cron job
echo "0 2 * * 0 /usr/local/bin/nextcloud-backup" >> /var/spool/cron/crontabs/root

# Set correct permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R www-data:www-data /var/www/nextcloud/
chmod -R 755 /var/www/nextcloud/

echo -e "${GREEN}=== Nextcloud Installation Complete! ===${NC}"
echo -e "${YELLOW}Access Nextcloud at: http://$(hostname -I | awk '{print $1}'):8081${NC}"
echo -e "${YELLOW}Admin user: admin${NC}"
echo -e "${YELLOW}Admin password: admin123${NC}"
echo -e "${RED}Please change the admin password immediately!${NC}"

# Display system status
echo -e "\n${GREEN}=== System Status ===${NC}"
systemctl is-active apache2 && echo -e "Apache2: ${GREEN}Running${NC}" || echo -e "Apache2: ${RED}Stopped${NC}"
systemctl is-active mariadb && echo -e "MariaDB: ${GREEN}Running${NC}" || echo -e "MariaDB: ${RED}Stopped${NC}"
systemctl is-active redis-server && echo -e "Redis: ${GREEN}Running${NC}" || echo -e "Redis: ${RED}Stopped${NC}"
systemctl is-active php8.1-fpm && echo -e "PHP-FPM: ${GREEN}Running${NC}" || echo -e "PHP-FPM: ${RED}Stopped${NC}"

echo -e "\n${GREEN}=== Disk Usage ===${NC}"
df -h /mnt/nas-storage
