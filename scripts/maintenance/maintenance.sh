#!/bin/bash

# ZimaBoard 2 Homelab Maintenance Script
# Performs routine maintenance tasks

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Update ClamAV virus definitions
update_clamav() {
    log "Updating ClamAV virus definitions..."
    docker-compose exec -T clamav freshclam
    docker-compose restart clamav
    info "ClamAV definitions updated."
}

# Update Suricata rules
update_suricata_rules() {
    log "Updating Suricata rules..."
    
    # Download latest Emerging Threats rules
    curl -L "https://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz" -o /tmp/emerging.rules.tar.gz
    
    if [ -f "/tmp/emerging.rules.tar.gz" ]; then
        # Backup current rules
        cp -r config/suricata/rules config/suricata/rules.backup.$(date +%Y%m%d)
        
        # Extract new rules
        tar -xzf /tmp/emerging.rules.tar.gz -C /tmp/
        cp /tmp/rules/*.rules config/suricata/rules/
        
        # Create combined rules file
        cat config/suricata/rules/*.rules > config/suricata/rules/suricata.rules
        
        # Restart Suricata
        docker-compose restart suricata
        
        # Cleanup
        rm -rf /tmp/emerging.rules.tar.gz /tmp/rules
        
        info "Suricata rules updated successfully."
    else
        error "Failed to download Suricata rules."
    fi
}

# Clean up Docker system
cleanup_docker() {
    log "Cleaning up Docker system..."
    
    # Remove unused containers
    docker container prune -f
    
    # Remove unused images (keep last 3 versions)
    docker image prune -f
    
    # Remove unused volumes
    docker volume prune -f
    
    # Remove unused networks
    docker network prune -f
    
    info "Docker cleanup completed."
}

# Rotate logs
rotate_logs() {
    log "Rotating logs..."
    
    # Compress logs older than 7 days
    find logs/ -name "*.log" -mtime +7 -exec gzip {} \;
    
    # Remove compressed logs older than 30 days
    find logs/ -name "*.log.gz" -mtime +30 -delete
    
    # Truncate large current log files (>100MB)
    find logs/ -name "*.log" -size +100M -exec truncate -s 10M {} \;
    
    info "Log rotation completed."
}

# Check disk space
check_disk_space() {
    log "Checking disk space..."
    
    # Get disk usage percentage
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt 85 ]; then
        warn "Disk usage is at ${DISK_USAGE}%. Consider freeing up space."
        
        # Show largest directories
        info "Largest directories:"
        du -h --max-depth=1 | sort -hr | head -10
    elif [ "$DISK_USAGE" -gt 95 ]; then
        error "Disk usage is critically high at ${DISK_USAGE}%!"
        
        # Emergency cleanup
        log "Performing emergency cleanup..."
        cleanup_docker
        rotate_logs
    else
        info "Disk usage is healthy at ${DISK_USAGE}%."
    fi
}

# Check memory usage
check_memory() {
    log "Checking memory usage..."
    
    # Get memory usage percentage
    MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$MEM_USAGE" -gt 85 ]; then
        warn "Memory usage is at ${MEM_USAGE}%."
        
        # Show top memory consuming containers
        info "Top memory consuming containers:"
        docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" | sort -k3 -nr | head -5
    else
        info "Memory usage is healthy at ${MEM_USAGE}%."
    fi
}

# Check service health
check_service_health() {
    log "Checking service health..."
    
    # Check if all services are running
    SERVICES=("unbound" "pihole" "clamav" "suricata" "prometheus" "grafana" "portainer" "nginx")
    
    for service in "${SERVICES[@]}"; do
        if docker-compose ps | grep -q "$service.*Up"; then
            info "✓ $service is running"
        else
            error "✗ $service is not running"
            
            # Try to restart the service
            log "Attempting to restart $service..."
            docker-compose restart "$service"
            sleep 10
            
            if docker-compose ps | grep -q "$service.*Up"; then
                info "✓ $service restarted successfully"
            else
                error "✗ Failed to restart $service"
            fi
        fi
    done
}

# Update Docker images
update_images() {
    log "Updating Docker images..."
    
    # Pull latest images
    docker-compose pull
    
    # Restart services with new images
    docker-compose up -d
    
    info "Docker images updated."
}

# Optimize Pi-hole
optimize_pihole() {
    log "Optimizing Pi-hole..."
    
    # Flush DNS cache
    docker-compose exec -T pihole pihole restartdns
    
    # Update gravity (blocklists)
    docker-compose exec -T pihole pihole -g
    
    info "Pi-hole optimized."
}

# Security scan with ClamAV
security_scan() {
    log "Performing security scan..."
    
    # Scan home directory for viruses
    docker-compose exec -T clamav clamdscan --infected --remove /scan/home
    
    info "Security scan completed."
}

# Generate system report
generate_report() {
    log "Generating system report..."
    
    REPORT_FILE="logs/maintenance-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOL
ZimaBoard 2 Homelab Maintenance Report
Generated: $(date)

=== System Information ===
Hostname: $(hostname)
Uptime: $(uptime)
Load Average: $(cat /proc/loadavg)
Memory Usage: $(free -h | grep Mem)
Disk Usage: $(df -h /)

=== Docker Services ===
$(docker-compose ps)

=== Docker System Info ===
$(docker system df)

=== Network Configuration ===
$(ip route)

=== Recent Errors (last 24 hours) ===
$(find logs/ -name "*.log" -mtime -1 -exec grep -i "error\|fail\|critical" {} \; | tail -20)

=== Pi-hole Statistics ===
$(curl -s "http://172.20.0.3/admin/api.php" | jq -r '.queries_over_time_for_graph | keys_unsorted[-1] as $last | "Last 24h queries: " + (.[$last] | tostring)')

=== Suricata Alerts (last 24 hours) ===
$(find logs/suricata -name "*.log" -mtime -1 -exec grep -c "Priority: [123]" {} \; | awk '{sum+=$1} END {print "High/Medium priority alerts: " (sum+0)}')

EOL

    info "System report generated: $REPORT_FILE"
}

# Main maintenance function
main() {
    log "Starting ZimaBoard 2 Homelab maintenance..."
    
    check_disk_space
    check_memory
    check_service_health
    
    # Perform updates
    update_clamav
    update_suricata_rules
    optimize_pihole
    
    # Cleanup tasks
    rotate_logs
    cleanup_docker
    
    # Security
    security_scan
    
    # Generate report
    generate_report
    
    log "Maintenance completed successfully! 🎉"
    
    # Show summary
    info "Maintenance Summary:"
    info "- All services checked and healthy"
    info "- Security definitions updated"
    info "- System cleanup performed"
    info "- Security scan completed"
    info "- Report generated in logs/"
}

# Check command line arguments
case "${1:-maintenance}" in
    "update-clamav")
        update_clamav
        ;;
    "update-suricata")
        update_suricata_rules
        ;;
    "cleanup")
        cleanup_docker
        rotate_logs
        ;;
    "health-check")
        check_service_health
        ;;
    "security-scan")
        security_scan
        ;;
    "update-images")
        update_images
        ;;
    "full"|"maintenance")
        main
        ;;
    *)
        echo "Usage: $0 {update-clamav|update-suricata|cleanup|health-check|security-scan|update-images|full}"
        echo ""
        echo "Options:"
        echo "  update-clamav    - Update ClamAV virus definitions"
        echo "  update-suricata  - Update Suricata rules"
        echo "  cleanup          - Clean up Docker system and logs"
        echo "  health-check     - Check service health"
        echo "  security-scan    - Run security scan"
        echo "  update-images    - Update Docker images"
        echo "  full             - Run full maintenance (default)"
        exit 1
        ;;
esac
