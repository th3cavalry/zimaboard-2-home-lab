#!/bin/bash

# ZimaBoard 2 Homelab Health Check Script
# Comprehensive monitoring and alerting for homelab services

set -euo pipefail

# Configuration
LOG_FILE="/var/log/homelab-health.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_TEMP=75

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Header function
print_header() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               ZimaBoard 2 Homelab Health Check              ║"  
    echo "║                    $(date '+%Y-%m-%d %H:%M:%S')                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check system resources
check_system_resources() {
    echo -e "\n${CYAN}═══ System Resources ═══${NC}"
    
    # CPU Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d' ' -f1)
    if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        error "CPU Usage: ${CPU_USAGE}% (High - Threshold: ${ALERT_THRESHOLD_CPU}%)"
    else
        success "CPU Usage: ${CPU_USAGE}%"
    fi
    
    # Memory Usage
    MEMORY_INFO=$(free | grep Mem)
    MEMORY_TOTAL=$(echo $MEMORY_INFO | awk '{print $2}')
    MEMORY_USED=$(echo $MEMORY_INFO | awk '{print $3}')
    MEMORY_PERCENT=$(echo "scale=1; $MEMORY_USED * 100 / $MEMORY_TOTAL" | bc)
    
    if (( $(echo "$MEMORY_PERCENT > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        error "Memory Usage: ${MEMORY_PERCENT}% (High - Threshold: ${ALERT_THRESHOLD_MEMORY}%)"
    else
        success "Memory Usage: ${MEMORY_PERCENT}%"
    fi
    
    # Disk Usage
    echo -e "\n${YELLOW}Disk Usage:${NC}"
    while IFS= read -r line; do
        FILESYSTEM=$(echo "$line" | awk '{print $1}')
        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT=$(echo "$line" | awk '{print $6}')
        
        if [[ "$USAGE" =~ ^[0-9]+$ ]]; then
            if (( USAGE > ALERT_THRESHOLD_DISK )); then
                error "  $MOUNT: ${USAGE}% (High - Threshold: ${ALERT_THRESHOLD_DISK}%)"
            else
                success "  $MOUNT: ${USAGE}%"
            fi
        fi
    done < <(df -h | grep -E '^/dev/')
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    info "Load Average:$LOAD_AVG"
    
    # Uptime
    UPTIME=$(uptime -p)
    info "Uptime: $UPTIME"
}

# Check temperature (if available)
check_temperature() {
    echo -e "\n${CYAN}═══ Temperature Monitoring ═══${NC}"
    
    if command -v sensors >/dev/null 2>&1; then
        # Try to get CPU temperature
        CPU_TEMP=$(sensors 2>/dev/null | grep -E "Core 0|CPU" | head -1 | awk '{print $3}' | sed 's/+//; s/°C//' | cut -d. -f1)
        
        if [[ -n "$CPU_TEMP" && "$CPU_TEMP" =~ ^[0-9]+$ ]]; then
            if (( CPU_TEMP > ALERT_THRESHOLD_TEMP )); then
                error "CPU Temperature: ${CPU_TEMP}°C (High - Threshold: ${ALERT_THRESHOLD_TEMP}°C)"
            else
                success "CPU Temperature: ${CPU_TEMP}°C"
            fi
        else
            info "CPU Temperature: Not available"
        fi
    else
        info "Temperature monitoring not available (lm-sensors not installed)"
    fi
}

# Check service status
check_services() {
    echo -e "\n${CYAN}═══ Service Status ═══${NC}"
    
    # Define services to check
    declare -A SERVICES=(
        ["nginx"]="Web Server"
        ["AdGuardHome"]="DNS Filter"
        ["php8.3-fpm"]="PHP Processor"
        ["fail2ban"]="Security Monitor"
        ["ufw"]="Firewall"
        ["ssh"]="SSH Server"
    )
    
    for service in "${!SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            success "${SERVICES[$service]} ($service): Running"
        else
            error "${SERVICES[$service]} ($service): Not running"
        fi
    done
}

# Check network connectivity
check_network() {
    echo -e "\n${CYAN}═══ Network Connectivity ═══${NC}"
    
    # Check internet connectivity
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connectivity: Available"
    else
        error "Internet connectivity: Not available"
    fi
    
    # Check DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        success "DNS resolution: Working"
    else
        error "DNS resolution: Not working"
    fi
    
    # Check local DNS (AdGuard Home)
    if curl -s --connect-timeout 5 http://localhost:3000 >/dev/null; then
        success "AdGuard Home web interface: Accessible"
    else
        error "AdGuard Home web interface: Not accessible"
    fi
    
    # Check Nextcloud
    if curl -s --connect-timeout 5 http://localhost:8080 >/dev/null; then
        success "Nextcloud web interface: Accessible" 
    else
        error "Nextcloud web interface: Not accessible"
    fi
}

# Check ports
check_ports() {
    echo -e "\n${CYAN}═══ Port Status ═══${NC}"
    
    declare -A PORTS=(
        ["80"]="HTTP Dashboard"
        ["22"]="SSH"
        ["53"]="DNS (AdGuard)"
        ["3000"]="AdGuard Web"
        ["8080"]="Nextcloud"
    )
    
    for port in "${!PORTS[@]}"; do
        if ss -tlnp | grep -q ":$port "; then
            success "${PORTS[$port]} (Port $port): Open"
        else
            error "${PORTS[$port]} (Port $port): Closed"
        fi
    done
}

# Check storage health
check_storage() {
    echo -e "\n${CYAN}═══ Storage Health ═══${NC}"
    
    # Check if smartctl is available
    if command -v smartctl >/dev/null 2>&1; then
        # Check SSD health
        if [[ -b /dev/sda ]]; then
            SMART_STATUS=$(sudo smartctl -H /dev/sda 2>/dev/null | grep "SMART overall-health" | awk '{print $6}')
            if [[ "$SMART_STATUS" == "PASSED" ]]; then
                success "SSD Health: PASSED"
            else
                error "SSD Health: $SMART_STATUS"
            fi
            
            # Get SSD temperature
            SSD_TEMP=$(sudo smartctl -A /dev/sda 2>/dev/null | grep Temperature | awk '{print $10}')
            if [[ -n "$SSD_TEMP" ]]; then
                info "SSD Temperature: ${SSD_TEMP}°C"
            fi
        else
            info "SSD (/dev/sda): Not detected"
        fi
    else
        info "Storage health monitoring not available (smartmontools not installed)"
    fi
    
    # Check mount points
    if mountpoint -q /mnt/ssd-data; then
        success "SSD Data mount: Mounted"
    else
        error "SSD Data mount: Not mounted"
    fi
}

# Check log files for errors
check_logs() {
    echo -e "\n${CYAN}═══ Recent Error Analysis ═══${NC}"
    
    # Check system logs for errors in last hour
    ERROR_COUNT=$(journalctl --since "1 hour ago" --priority=err --quiet | wc -l)
    if (( ERROR_COUNT > 0 )); then
        warning "System errors in last hour: $ERROR_COUNT"
    else
        success "No system errors in last hour"
    fi
    
    # Check specific service logs
    declare -A LOG_SERVICES=(
        ["nginx"]="Web Server"
        ["AdGuardHome"]="DNS Filter"
        ["fail2ban"]="Security Monitor"
    )
    
    for service in "${!LOG_SERVICES[@]}"; do
        SERVICE_ERRORS=$(journalctl -u "$service" --since "1 hour ago" --priority=err --quiet | wc -l)
        if (( SERVICE_ERRORS > 0 )); then
            warning "${LOG_SERVICES[$service]} errors in last hour: $SERVICE_ERRORS"
        else
            success "${LOG_SERVICES[$service]}: No recent errors"
        fi
    done
}

# Check security status
check_security() {
    echo -e "\n${CYAN}═══ Security Status ═══${NC}"
    
    # Check fail2ban status
    if command -v fail2ban-client >/dev/null 2>&1; then
        BANNED_IPS=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list" | awk -F: '{print $2}' | wc -w)
        info "Fail2ban banned IPs: $BANNED_IPS"
    fi
    
    # Check UFW status
    if ufw status | grep -q "Status: active"; then
        success "Firewall (UFW): Active"
    else
        error "Firewall (UFW): Inactive"
    fi
    
    # Check for unauthorized SSH attempts
    SSH_FAILS=$(journalctl --since "24 hours ago" | grep "Failed password" | wc -l)
    if (( SSH_FAILS > 10 )); then
        warning "SSH login failures in last 24h: $SSH_FAILS (High activity detected)"
    else
        info "SSH login failures in last 24h: $SSH_FAILS"
    fi
}

# Generate summary
generate_summary() {
    echo -e "\n${PURPLE}═══ Health Check Summary ═══${NC}"
    
    # Count issues
    ERROR_COUNT=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "\[WARNING\]" "$LOG_FILE" 2>/dev/null || echo "0")
    SUCCESS_COUNT=$(grep -c "\[OK\]" "$LOG_FILE" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ Passed checks: $SUCCESS_COUNT${NC}"
    
    if (( WARNING_COUNT > 0 )); then
        echo -e "${YELLOW}⚠ Warnings: $WARNING_COUNT${NC}"
    fi
    
    if (( ERROR_COUNT > 0 )); then
        echo -e "${RED}✗ Errors: $ERROR_COUNT${NC}"
    fi
    
    # Overall health status
    echo -e "\n${PURPLE}Overall System Health:${NC}"
    if (( ERROR_COUNT == 0 && WARNING_COUNT == 0 )); then
        echo -e "${GREEN}🟢 EXCELLENT - All systems operational${NC}"
    elif (( ERROR_COUNT == 0 && WARNING_COUNT <= 2 )); then
        echo -e "${YELLOW}🟡 GOOD - Minor warnings detected${NC}"
    elif (( ERROR_COUNT <= 2 )); then
        echo -e "${YELLOW}🟠 FAIR - Some issues need attention${NC}"
    else
        echo -e "${RED}🔴 POOR - Multiple critical issues detected${NC}"
    fi
}

# Main function
main() {
    # Clear previous log for this run
    echo "=== Health Check Started $(date) ===" > "$LOG_FILE"
    
    print_header
    check_system_resources
    check_temperature
    check_services
    check_network
    check_ports
    check_storage
    check_logs
    check_security
    generate_summary
    
    echo -e "\n${BLUE}Health check completed. Full log: $LOG_FILE${NC}"
}

# Run main function
main "$@"
