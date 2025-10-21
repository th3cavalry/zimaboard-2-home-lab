#!/bin/bash
################################################################################
# Nextcloud Installation Module
# Part of ZimaBoard 2 Homelab Installation System
################################################################################

install_nextcloud() {
    print_info "☁️ Installing Nextcloud personal cloud..."
    
    # Install required packages
    print_info "Installing PHP and database packages..."
    apt install -y \
        php php-fpm php-mysql php-pgsql php-sqlite3 \
        php-redis php-memcached \
        php-gd php-imagick \
        php-json php-curl \
        php-zip php-xml php-mbstring \
        php-bz2 php-intl php-gmp \
        php-bcmath php-smbclient \
        mariadb-server mariadb-client \
        redis-server \
        unzip
    
    # Get actual PHP version
    ACTUAL_PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    
    # Configure MariaDB
    print_info "Configuring MariaDB database..."
    systemctl start mariadb
    systemctl enable mariadb
    
    # Secure MariaDB and create Nextcloud database
    mysql -u root << 'MYSQL_EOF'
UPDATE mysql.user SET Password = PASSWORD('admin123') WHERE User = 'root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'nextcloud123';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
MYSQL_EOF
    
    # Download latest Nextcloud
    print_info "Downloading Nextcloud..."
    cd /tmp
    NEXTCLOUD_VERSION="31.0.9"
    wget https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2
    
    # Extract and install
    tar -xjf nextcloud-${NEXTCLOUD_VERSION}.tar.bz2
    cp -r nextcloud /var/www/
    chown -R www-data:www-data /var/www/nextcloud
    
    # Create Nextcloud data directory
    mkdir -p ${DATA_DIR}/nextcloud
    chown -R www-data:www-data ${DATA_DIR}/nextcloud
    
    # Configure PHP for Nextcloud
    print_info "Optimizing PHP configuration..."
    sed -i 's/memory_limit = .*/memory_limit = 1G/' /etc/php/*/fpm/php.ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 16G/' /etc/php/*/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 16G/' /etc/php/*/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 3600/' /etc/php/*/fpm/php.ini
    sed -i 's/max_input_time = .*/max_input_time = 3600/' /etc/php/*/fpm/php.ini
    
    # Enable required PHP modules
    phpenmod gd imagick intl mbstring mysql zip xml curl bz2 gmp bcmath redis
    
    # Install Nextcloud via command line (automated setup)
    print_info "Configuring Nextcloud..."
    cd /var/www/nextcloud
    sudo -u www-data php occ maintenance:install \
        --database="mysql" \
        --database-name="nextcloud" \
        --database-user="nextcloud" \
        --database-pass="nextcloud123" \
        --admin-user="admin" \
        --admin-pass="admin123" \
        --data-dir="${DATA_DIR}/nextcloud"
    
    # Configure trusted domains
    sudo -u www-data php occ config:system:set trusted_domains 0 --value="localhost"
    sudo -u www-data php occ config:system:set trusted_domains 1 --value="192.168.8.2"
    sudo -u www-data php occ config:system:set trusted_domains 2 --value="zimaboard"
    
    # Configure Redis cache
    sudo -u www-data php occ config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
    sudo -u www-data php occ config:system:set memcache.distributed --value="\\OC\\Memcache\\Redis"
    sudo -u www-data php occ config:system:set redis host --value="localhost"
    sudo -u www-data php occ config:system:set redis port --value=6379
    
    # Configure background jobs to use cron
    sudo -u www-data php occ background:cron
    
    # Set up cron job for Nextcloud
    (crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f /var/www/nextcloud/cron.php") | crontab -u www-data -
    
    # Enable pretty URLs
    sudo -u www-data php occ config:system:set htaccess.RewriteBase --value="/"
    sudo -u www-data php occ maintenance:update:htaccess
    
    # Create Nextcloud virtual host for Nginx
    cat > /etc/nginx/sites-available/nextcloud << 'NGINXEOF'
server {
    listen 8000;
    server_name _;
    root /var/www/nextcloud;
    index index.php index.html;

    add_header Referrer-Policy "no-referrer" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-XSS-Protection "1; mode=block" always;

    fastcgi_hide_header X-Powered-By;

    location = / {
        if ( $http_user_agent ~ ^DavClnt ) {
            return 302 /remote.php/webdav/$is_args$args;
        }
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ^~ /.well-known {
        location = /.well-known/carddav { return 301 /remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /remote.php/dav/; }
        location = /.well-known/webfinger  { return 301 /index.php/.well-known/webfinger; }
        location = /.well-known/nodeinfo  { return 301 /index.php/.well-known/nodeinfo; }
        location /.well-known/acme-challenge { try_files $uri $uri/ =404; }
        location /.well-known/pki-validation { try_files $uri $uri/ =404; }
        return 301 /index.php$request_uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)  { return 404; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)                { return 404; }

    location ~ \.php(?:$|/) {
        rewrite ^/(?!index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|oc[ms]-provider/.+|.+/richdocumentscode/proxy) /index.php$request_uri;

        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        set $path_info $fastcgi_path_info;

        try_files $fastcgi_script_name =404;

        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $path_info;
        fastcgi_param HTTPS off;

        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/run/php/phpPHP_VERSION-fpm.sock;

        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;

        fastcgi_max_temp_file_size 0;
        fastcgi_buffering off;
    }

    location ~ \.(?:css|js|svg|gif|png|jpg|ico|wasm|tflite|map|ogg|flac)$ {
        try_files $uri /index.php$request_uri;
        add_header Cache-Control "public, max-age=15778463, immutable";
        access_log off;
    }

    location ~ \.woff2?$ {
        try_files $uri /index.php$request_uri;
        expires 7d;
        access_log off;
    }

    location /remote {
        return 301 /remote.php$request_uri;
    }

    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
NGINXEOF
    
    # Substitute the actual PHP version
    sed -i "s/PHP_VERSION/${ACTUAL_PHP_VERSION}/g" /etc/nginx/sites-available/nextcloud
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
    
    # Restart services
    systemctl restart php*-fpm
    systemctl restart redis-server
    systemctl restart mariadb
    systemctl reload nginx
    
    # Configure firewall
    ufw allow 8000/tcp comment "Nextcloud"
    
    # Clean up
    rm -rf /tmp/nextcloud-${NEXTCLOUD_VERSION}.tar.bz2 /tmp/nextcloud
    
    print_success "✅ Nextcloud personal cloud installed and configured"
    print_info "   Web Interface: http://192.168.8.2:8000"
    print_info "   Default login: admin / admin123"
    print_warning "   ⚠️ Change the password after first login!"
    
    return 0
}

# Export function for use by main installer
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f install_nextcloud
fi
