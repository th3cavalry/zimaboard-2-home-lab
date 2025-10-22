#!/bin/bash
################################################################################
# ZimaBoard Homelab - Health Check Script
# 
# This script verifies that all deployed services are running correctly:
# - Docker services are running
# - Ports are accessible
# - DNS resolution is working
# - Lancache is responding
# - Samba is accessible
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Health check counters
PASSED=0
FAILED=0
WARNINGS=0

# Logging functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Header
echo "=================================="
echo "     Homelab Health Check"
echo "=================================="
echo

# Get the script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repository root
cd "$REPO_ROOT"

################################################################################
# Step 1: Check if Docker is running
################################################################################

info "Step 1: Checking Docker..."
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        pass "Docker daemon is running"
    else
        fail "Docker daemon is not running"
        echo "  Start it with: sudo systemctl start docker"
    fi
else
    fail "Docker is not installed"
fi
echo

################################################################################
# Step 2: Check Docker Compose services
################################################################################

info "Step 2: Checking Docker Compose services..."

if [[ ! -f docker-compose.yml ]]; then
    fail "docker-compose.yml not found in current directory"
    exit 1
fi

if docker compose ps &> /dev/null; then
    SERVICES=$(docker compose ps --format json 2>/dev/null | jq -r '.Service' 2>/dev/null || docker compose ps --services 2>/dev/null)
    
    if [[ -z "$SERVICES" ]]; then
        warn "No services are running"
        echo "  Start services with: docker compose up -d"
    else
        for service in $SERVICES; do
            STATUS=$(docker compose ps $service --format json 2>/dev/null | jq -r '.State' 2>/dev/null || docker compose ps $service 2>/dev/null | tail -1 | awk '{print $4}')
            if [[ "$STATUS" =~ "running" ]] || [[ "$STATUS" == "Up" ]]; then
                pass "Service '$service' is running"
            else
                fail "Service '$service' is not running (status: $STATUS)"
            fi
        done
    fi
else
    warn "Could not check Docker Compose services"
fi
echo

################################################################################
# Step 3: Check service ports
################################################################################

info "Step 3: Checking service ports..."

check_port() {
    local port=$1
    local service=$2
    local protocol=${3:-tcp}
    
    # Check if something is listening on the port
    if sudo lsof -i $protocol:$port &> /dev/null || ss -tuln 2>/dev/null | grep -q ":$port "; then
        # Try to connect
        if timeout 2 bash -c "echo > /dev/tcp/localhost/$port" 2>/dev/null; then
            pass "Port $port ($service) is accessible"
        else
            warn "Port $port ($service) is open but not responding"
        fi
    else
        fail "Port $port ($service) is not listening"
    fi
}

# Check common service ports
check_port 3000 "AdGuard Web Interface"
check_port 53 "AdGuard DNS" "udp"
check_port 8080 "Lancache HTTP"
check_port 445 "Samba"
echo

################################################################################
# Step 4: Check DNS resolution
################################################################################

info "Step 4: Checking DNS resolution..."

# Load .env if it exists to get SERVER_IP
if [[ -f .env ]]; then
    set -a
    source .env 2>/dev/null || true
    set +a
fi

SERVER_IP="${SERVER_IP:-127.0.0.1}"

# Check if AdGuard DNS is working
if command -v dig &> /dev/null; then
    if dig @$SERVER_IP google.com +short +time=2 &> /dev/null; then
        RESULT=$(dig @$SERVER_IP google.com +short +time=2 | head -1)
        if [[ -n "$RESULT" ]]; then
            pass "DNS resolution working (got: $RESULT)"
        else
            fail "DNS query returned no results"
        fi
    else
        fail "DNS resolution failed"
        echo "  Check AdGuard Home is running and listening on port 53"
    fi
elif command -v nslookup &> /dev/null; then
    if timeout 2 nslookup google.com $SERVER_IP &> /dev/null; then
        pass "DNS resolution working"
    else
        fail "DNS resolution failed"
    fi
else
    warn "DNS testing tools (dig/nslookup) not available"
fi
echo

################################################################################
# Step 5: Check Lancache
################################################################################

info "Step 5: Checking Lancache..."

# Check if Lancache container is running
if docker ps --format "{{.Names}}" | grep -q lancache; then
    pass "Lancache container is running"
    
    # Check Lancache HTTP endpoint
    if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080 2>/dev/null | grep -q "200\|301\|302\|404"; then
        pass "Lancache HTTP endpoint responding"
    else
        warn "Lancache HTTP endpoint not responding"
    fi
else
    warn "Lancache container is not running"
fi
echo

################################################################################
# Step 6: Check AdGuard Home
################################################################################

info "Step 6: Checking AdGuard Home..."

if docker ps --format "{{.Names}}" | grep -q adguard; then
    pass "AdGuard Home container is running"
    
    # Check AdGuard web interface
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
        pass "AdGuard Home web interface responding (HTTP $HTTP_CODE)"
    else
        warn "AdGuard Home web interface not responding properly (HTTP $HTTP_CODE)"
    fi
else
    warn "AdGuard Home container is not running"
fi
echo

################################################################################
# Step 7: Check Samba
################################################################################

info "Step 7: Checking Samba..."

if docker ps --format "{{.Names}}" | grep -q samba; then
    pass "Samba container is running"
    
    # Check if Samba port is listening
    if ss -tuln 2>/dev/null | grep -q ":445 " || sudo lsof -i :445 &> /dev/null; then
        pass "Samba port (445) is listening"
        
        # Try to list shares if smbclient is available
        if command -v smbclient &> /dev/null; then
            if timeout 5 smbclient -L localhost -N &> /dev/null; then
                pass "Samba shares are accessible"
                info "Available shares:"
                smbclient -L localhost -N 2>/dev/null | grep "Disk" | awk '{print "  - " $1}'
            else
                warn "Could not list Samba shares"
            fi
        else
            info "smbclient not available for testing (optional)"
        fi
    else
        fail "Samba port (445) is not listening"
    fi
else
    warn "Samba container is not running"
fi
echo

################################################################################
# Step 8: Check storage mounts
################################################################################

info "Step 8: Checking storage mounts..."

if [[ -f .env ]]; then
    set -a
    source .env 2>/dev/null || true
    set +a
    
    # Check SSD mount
    if [[ -n "${DATA_PATH_SSD:-}" ]]; then
        if mountpoint -q "$DATA_PATH_SSD" 2>/dev/null || [[ -d "$DATA_PATH_SSD" ]]; then
            pass "SSD path exists: $DATA_PATH_SSD"
            
            if [[ -d "$DATA_PATH_SSD/fileshare" ]]; then
                pass "Fileshare directory exists"
            else
                warn "Fileshare directory not found: $DATA_PATH_SSD/fileshare"
            fi
        else
            fail "SSD path not found: $DATA_PATH_SSD"
        fi
    fi
    
    # Check HDD mount
    if [[ -n "${DATA_PATH_HDD:-}" ]]; then
        if mountpoint -q "$DATA_PATH_HDD" 2>/dev/null || [[ -d "$DATA_PATH_HDD" ]]; then
            pass "HDD path exists: $DATA_PATH_HDD"
            
            if [[ -d "$DATA_PATH_HDD/lancache" ]]; then
                pass "Lancache directory exists"
            else
                warn "Lancache directory not found: $DATA_PATH_HDD/lancache"
            fi
        else
            fail "HDD path not found: $DATA_PATH_HDD"
        fi
    fi
else
    warn ".env file not found, skipping storage mount checks"
fi
echo

################################################################################
# Step 9: Check disk space
################################################################################

info "Step 9: Checking disk space..."

if [[ -f .env ]]; then
    set -a
    source .env 2>/dev/null || true
    set +a
    
    # Check SSD space
    if [[ -n "${DATA_PATH_SSD:-}" ]] && [[ -d "$DATA_PATH_SSD" ]]; then
        SSD_USAGE=$(df -h "$DATA_PATH_SSD" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $SSD_USAGE -lt 80 ]]; then
            pass "SSD space usage: ${SSD_USAGE}%"
        elif [[ $SSD_USAGE -lt 90 ]]; then
            warn "SSD space usage: ${SSD_USAGE}% (getting high)"
        else
            fail "SSD space usage: ${SSD_USAGE}% (critically high)"
        fi
    fi
    
    # Check HDD space
    if [[ -n "${DATA_PATH_HDD:-}" ]] && [[ -d "$DATA_PATH_HDD" ]]; then
        HDD_USAGE=$(df -h "$DATA_PATH_HDD" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $HDD_USAGE -lt 80 ]]; then
            pass "HDD space usage: ${HDD_USAGE}%"
        elif [[ $HDD_USAGE -lt 90 ]]; then
            warn "HDD space usage: ${HDD_USAGE}% (getting high)"
        else
            fail "HDD space usage: ${HDD_USAGE}% (critically high)"
        fi
    fi
fi
echo

################################################################################
# Summary
################################################################################

echo "=================================="
echo "       Health Check Summary"
echo "=================================="
echo

TOTAL=$((PASSED + FAILED + WARNINGS))

echo -e "${GREEN}Passed:   $PASSED${NC}"
echo -e "${RED}Failed:   $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo "Total:    $TOTAL"
echo

if [[ $FAILED -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All health checks passed!${NC}"
    echo "Your homelab is running smoothly."
    exit 0
elif [[ $FAILED -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Health check completed with warnings${NC}"
    echo "Review the warnings above. Your homelab is mostly functional."
    exit 0
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Review the failures above and take corrective action."
    echo
    echo "Common fixes:"
    echo "  - Start services: docker compose up -d"
    echo "  - Check logs: docker compose logs -f"
    echo "  - Restart services: docker compose restart"
    exit 1
fi
