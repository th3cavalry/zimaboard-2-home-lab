#!/bin/bash
################################################################################
# Nginx Web Server Installation Module
# Part of ZimaBoard 2 Homelab Installation System
################################################################################

install_nginx() {
    print_info "🌐 Installing and configuring Nginx web server..."
    
    # Stop and disable Apache2 (if installed) to prevent conflicts
    systemctl stop apache2 2>/dev/null || true
    systemctl disable apache2 2>/dev/null || true
    systemctl mask apache2 2>/dev/null || true
    
    # Install Nginx
    apt install -y nginx apache2-utils
    
    # Create main dashboard configuration
    print_info "Setting up web dashboard..."
    cat > /etc/nginx/sites-available/dashboard << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
    
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /adguard/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /netdata/ {
        proxy_pass http://127.0.0.1:19999/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF
    
    # Create homelab dashboard
    print_info "Creating homelab dashboard..."
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZimaBoard 2 Homelab</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            color: white;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
        }
        
        .service {
            background: rgba(255, 255, 255, 0.95);
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .service:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.2);
        }
        
        .service-icon {
            font-size: 2.5em;
            margin-bottom: 15px;
        }
        
        .service h3 {
            color: #333;
            margin-bottom: 10px;
            font-size: 1.4em;
        }
        
        .service p {
            color: #666;
            margin-bottom: 15px;
            line-height: 1.6;
        }
        
        .status {
            display: inline-block;
            padding: 5px 12px;
            background: #28a745;
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
            margin-bottom: 15px;
        }
        
        .service-button {
            display: inline-block;
            padding: 12px 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 500;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        
        .service-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .config-info {
            background: rgba(255, 255, 255, 0.1);
            padding: 10px;
            border-radius: 8px;
            margin-top: 10px;
            font-family: monospace;
            font-size: 0.9em;
            color: #333;
        }
        
        .footer {
            margin-top: 50px;
            text-align: center;
            color: white;
            opacity: 0.8;
        }
        
        .footer p {
            margin: 5px 0;
        }
        
        @media (max-width: 768px) {
            .services {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 ZimaBoard 2 Homelab</h1>
            <p>Your complete security and productivity homelab</p>
        </div>
        
        <div class="services">
            <div class="service">
                <div class="service-icon">🛡️</div>
                <h3>AdGuard Home DNS</h3>
                <p>Modern DNS filtering with DNS-over-HTTPS, beautiful UI, and advanced features</p>
                <div class="status">● Active</div>
                <a href="http://192.168.8.2:3000" class="service-button">Admin Interface</a>
            </div>
            
            <div class="service">
                <div class="service-icon">☁️</div>
                <h3>Nextcloud Personal Cloud</h3>
                <p>Feature-rich personal cloud with file sync, calendar, contacts, and office suite</p>
                <div class="status">● Active</div>
                <a href="http://192.168.8.2:8000" class="service-button">Access Nextcloud</a>
            </div>
            
            <div class="service">
                <div class="service-icon">📊</div>
                <h3>Netdata System Monitoring</h3>
                <p>Real-time system performance monitoring with beautiful dashboards</p>
                <div class="status">● Active</div>
                <a href="http://192.168.8.2:19999" class="service-button">View Metrics</a>
            </div>
            
            <div class="service">
                <div class="service-icon">🔄</div>
                <h3>Squid Proxy Cache</h3>
                <p>Bandwidth optimization for cellular internet connections</p>
                <div class="status">● Active</div>
                <div class="config-info">
                    Configure devices to use:<br>
                    <strong>192.168.8.2:3128</strong>
                </div>
            </div>
            
            <div class="service">
                <div class="service-icon">🔐</div>
                <h3>WireGuard VPN Server</h3>
                <p>Secure remote access to your home network from anywhere</p>
                <div class="status">● Active</div>
                <div class="config-info">
                    Client config location:<br>
                    <strong>/etc/wireguard/client.conf</strong>
                </div>
            </div>
            
            <div class="service">
                <div class="service-icon">🔥</div>
                <h3>UFW Security Firewall</h3>
                <p>Advanced firewall protecting all your homelab services</p>
                <div class="status">● Active</div>
                <div class="config-info">
                    Check status: <strong>sudo ufw status</strong>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>🚀 <strong>ZimaBoard 2 Homelab</strong> - Ubuntu Server Edition</p>
            <p>No containers • No complexity • Just works</p>
            <p>Built with ❤️ for the homelab community</p>
        </div>
    </div>
    
    <script>
        // Add some interactivity
        document.addEventListener('DOMContentLoaded', function() {
            // Check service status (placeholder for future enhancement)
            console.log('ZimaBoard 2 Homelab Dashboard Loaded');
            
            // Add click tracking
            document.querySelectorAll('.service-button').forEach(button => {
                button.addEventListener('click', function() {
                    console.log('Accessing:', this.getAttribute('href'));
                });
            });
        });
    </script>
</body>
</html>
HTMLEOF
    
    # Enable the dashboard site
    ln -sf /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    nginx -t
    
    # Enable and start Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    # Configure firewall
    ufw allow 80/tcp comment "Nginx HTTP"
    ufw allow 443/tcp comment "Nginx HTTPS"
    
    print_success "✅ Nginx web server installed and configured"
    print_info "   Main Dashboard: http://192.168.8.2"
    print_info "   AdGuard Home proxy: http://192.168.8.2/adguard/"
    print_info "   Netdata proxy: http://192.168.8.2/netdata/"
    
    return 0
}

# Export function for use by main installer
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f install_nginx
fi
