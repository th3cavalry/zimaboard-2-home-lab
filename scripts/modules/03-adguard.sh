#!/bin/bash
################################################################################
# AdGuard Home Installation Module
# Part of ZimaBoard 2 Homelab Installation System
################################################################################

install_adguard() {
    print_info "🛡️ Installing AdGuard Home DNS server..."
    
    # Create directories
    ADGUARD_INSTALL_DIR="/opt/AdGuardHome"
    ADGUARD_WORK_DIR="${DATA_DIR}/adguardhome"
    mkdir -p "$ADGUARD_INSTALL_DIR"
    mkdir -p "$ADGUARD_WORK_DIR"
    
    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ADGUARD_ARCH="amd64"
            ;;
        aarch64|arm64)
            ADGUARD_ARCH="arm64"
            ;;
        armv7l|armhf)
            ADGUARD_ARCH="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    # Download latest AdGuard Home
    print_info "Fetching latest AdGuard Home release..."
    ADGUARD_VERSION=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    ADGUARD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz"
    
    print_info "Downloading AdGuard Home $ADGUARD_VERSION..."
    cd /tmp
    curl -L -o AdGuardHome.tar.gz "$ADGUARD_URL"
    tar -xzf AdGuardHome.tar.gz
    cd AdGuardHome
    mv AdGuardHome "$ADGUARD_INSTALL_DIR/"
    chmod +x "$ADGUARD_INSTALL_DIR/AdGuardHome"
    cd /
    rm -rf /tmp/AdGuardHome /tmp/AdGuardHome.tar.gz
    
    # Create AdGuard Home configuration with DNS-over-HTTPS
    print_info "Configuring AdGuard Home with DNS-over-HTTPS..."
    cat > "$ADGUARD_WORK_DIR/AdGuardHome.yaml" << 'AGHEOF'
bind_host: 0.0.0.0
bind_port: 3000
users:
  - name: admin
    password: $2a$10$jU3FqELn3cqV/4gkH5w5z.mf5h9q2lZ8L6rG5tF8uVwK7u6p5F5G.
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: en
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  ratelimit: 0
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
    - https://dns.quad9.net/dns-query
  upstream_dns_file: ""
  bootstrap_dns:
    - 1.1.1.1
    - 1.0.0.1
    - 8.8.8.8
  fallback_dns: []
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: false
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
tls:
  enabled: false
querylog:
  enabled: true
  file_enabled: true
  interval: 2160h
  size_memory: 1000
  ignored: []
statistics:
  enabled: true
  interval: 24h
  ignored: []
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: https://someonewhocares.org/hosts/zero/hosts
    name: Dan Pollock's List
    id: 3
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 27
AGHEOF
    
    # Install as service
    cd "$ADGUARD_INSTALL_DIR"
    ./AdGuardHome -s install -w "$ADGUARD_WORK_DIR"
    systemctl enable AdGuardHome
    systemctl start AdGuardHome
    
    # Configure firewall
    ufw allow 53/tcp comment "AdGuard Home DNS"
    ufw allow 53/udp comment "AdGuard Home DNS"
    ufw allow 3000/tcp comment "AdGuard Home Web UI"
    
    print_success "✅ AdGuard Home installed and configured"
    print_info "   Web Interface: http://192.168.8.2:3000"
    print_info "   Default login: admin / admin123"
    print_warning "   ⚠️ Change the password after first login!"
    
    return 0
}

# Export function for use by main installer
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f install_adguard
fi
