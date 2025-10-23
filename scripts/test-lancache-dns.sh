#!/bin/bash
################################################################################
# Lancache DNS Resolution Test Script
# 
# This script tests DNS resolution for Lancache domains to verify that both
# base domains and wildcard subdomains are correctly configured in AdGuard Home.
#
# Usage:
#   bash scripts/test-lancache-dns.sh [DNS_SERVER_IP]
#
# Example:
#   bash scripts/test-lancache-dns.sh 192.168.8.2
#
# The script will test DNS resolution for both base domains (e.g., steamcontent.com)
# and wildcard subdomains (e.g., cdn.steamcontent.com) to ensure they all resolve
# to your Lancache server IP.
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default DNS server IP (can be overridden by command line argument)
DNS_SERVER="${1:-192.168.8.2}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Lancache DNS Resolution Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Testing DNS server: ${YELLOW}${DNS_SERVER}${NC}"
echo ""

# Check if nslookup is available
if ! command -v nslookup &> /dev/null; then
    echo -e "${RED}Error: nslookup command not found. Please install dnsutils:${NC}"
    echo "  Ubuntu/Debian: sudo apt install dnsutils"
    echo "  Fedora/RHEL: sudo dnf install bind-utils"
    exit 1
fi

# Test domains - both base and wildcard subdomain
declare -A test_domains=(
    ["steamcontent.com"]="cdn.steamcontent.com"
    ["download.epicgames.com"]="download1.epicgames.com"
    ["origin.com"]="lvlt.cdn.ea.com.origin.com"
    ["xboxlive.com"]="dl.delivery.mp.microsoft.com.xboxlive.com"
    ["playstation.net"]="gs2.ww.prod.dl.playstation.net"
    ["blizzard.com"]="dist.blizzard.com"
    ["windowsupdate.com"]="download.windowsupdate.com"
)

total_tests=0
passed_tests=0
failed_tests=0

# Function to test DNS resolution
test_dns_resolution() {
    local domain=$1
    local expected_ip=$2
    
    # Use nslookup to query the DNS server
    result=$(nslookup "$domain" "$DNS_SERVER" 2>&1)
    
    # Check if we got an answer
    if echo "$result" | grep -q "server can't find"; then
        echo -e "  ${RED}✗ FAIL${NC} - No answer from DNS server"
        return 1
    elif echo "$result" | grep -q "NXDOMAIN"; then
        echo -e "  ${RED}✗ FAIL${NC} - Domain not found (NXDOMAIN)"
        return 1
    elif echo "$result" | grep -q "$expected_ip"; then
        echo -e "  ${GREEN}✓ PASS${NC} - Resolved to ${expected_ip}"
        return 0
    else
        # Extract the actual IP from the result
        actual_ip=$(echo "$result" | grep -A1 "Name:" | grep "Address:" | tail -1 | awk '{print $2}')
        if [ -z "$actual_ip" ]; then
            actual_ip="(unknown)"
        fi
        echo -e "  ${RED}✗ FAIL${NC} - Resolved to ${actual_ip} instead of ${expected_ip}"
        return 1
    fi
}

echo -e "${BLUE}Testing DNS Resolution:${NC}"
echo ""

# Test each domain pair (base domain + wildcard subdomain)
for base_domain in "${!test_domains[@]}"; do
    wildcard_subdomain="${test_domains[$base_domain]}"
    
    echo -e "${YELLOW}Testing: ${base_domain}${NC}"
    total_tests=$((total_tests + 1))
    if test_dns_resolution "$base_domain" "$DNS_SERVER"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    echo -e "${YELLOW}Testing: ${wildcard_subdomain}${NC}"
    total_tests=$((total_tests + 1))
    if test_dns_resolution "$wildcard_subdomain" "$DNS_SERVER"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
done

# Print summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total tests:  ${total_tests}"
echo -e "Passed:       ${GREEN}${passed_tests}${NC}"
echo -e "Failed:       ${RED}${failed_tests}${NC}"
echo ""

if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Lancache DNS is configured correctly.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Verify Lancache container is running: docker compose ps lancache"
    echo "2. Download a game or update to test cache functionality"
    echo "3. Check Lancache logs for cache HIT/MISS: docker compose logs -f lancache"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Lancache DNS may not be configured correctly.${NC}"
    echo ""
    echo -e "${BLUE}Troubleshooting steps:${NC}"
    echo "1. Check if AdGuard Home is running: docker compose ps adguardhome"
    echo "2. Verify DNS rewrites in AdGuard Home web interface:"
    echo "   - Navigate to http://${DNS_SERVER}:3000"
    echo "   - Go to Filters → DNS rewrites"
    echo "   - Ensure all 14 rewrites are configured (7 base + 7 wildcard)"
    echo "3. Check if the server IP in configs/adguardhome/AdGuardHome.yaml"
    echo "   matches your actual server IP (${DNS_SERVER})"
    echo "4. Restart AdGuard Home: docker compose restart adguardhome"
    exit 1
fi
