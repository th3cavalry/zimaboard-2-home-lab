#!/bin/bash

# Test script for eMMC optimization validation
# This script checks if eMMC optimizations are properly applied

set -e

echo "🔍 Testing eMMC Optimization Configuration..."
echo "=============================================="

# Test 1: Check fstab mount options
echo "📋 Test 1: Checking /etc/fstab mount options..."
if grep -q "noatime" /etc/fstab && grep -q "commit=" /etc/fstab; then
    echo "✅ Mount options found in /etc/fstab"
else
    echo "❌ Mount options not found in /etc/fstab"
fi

# Test 2: Check TRIM timer
echo "📋 Test 2: Checking TRIM timer status..."
if systemctl is-enabled fstrim.timer &>/dev/null; then
    echo "✅ TRIM timer is enabled"
else
    echo "❌ TRIM timer is not enabled"
fi

# Test 3: Check tmpfs mounts
echo "📋 Test 3: Checking tmpfs configuration..."
if grep -q "tmpfs /tmp" /etc/fstab && grep -q "tmpfs /var/tmp" /etc/fstab; then
    echo "✅ tmpfs configuration found"
else
    echo "❌ tmpfs configuration not found"
fi

# Test 4: Check systemd journal settings
echo "📋 Test 4: Checking systemd journal optimization..."
if [[ -f /etc/systemd/journald.conf.d/emmc-optimization.conf ]]; then
    echo "✅ Journal optimization configuration found"
else
    echo "❌ Journal optimization configuration not found"
fi

# Test 5: Check kernel parameters
echo "📋 Test 5: Checking kernel parameters..."
if [[ -f /etc/sysctl.d/emmc-optimization.conf ]]; then
    echo "✅ Kernel parameter optimization found"
else
    echo "❌ Kernel parameter optimization not found"
fi

# Test 6: Check I/O scheduler rules
echo "📋 Test 6: Checking I/O scheduler rules..."
if [[ -f /etc/udev/rules.d/60-emmc-scheduler.rules ]]; then
    echo "✅ I/O scheduler rules found"
else
    echo "❌ I/O scheduler rules not found"
fi

# Test 7: Check health monitoring
echo "📋 Test 7: Checking health monitoring..."
if systemctl is-enabled emmc-health-check.timer &>/dev/null; then
    echo "✅ Health monitoring timer enabled"
else
    echo "❌ Health monitoring timer not enabled"
fi

# Test 8: Check maintenance scripts
echo "📋 Test 8: Checking maintenance scripts..."
if [[ -x /usr/local/bin/emmc-maintenance.sh ]] && [[ -x /usr/local/bin/emmc-health-check.sh ]]; then
    echo "✅ Maintenance scripts installed and executable"
else
    echo "❌ Maintenance scripts not found or not executable"
fi

# Test 9: Check current mount options (if mounted)
echo "📋 Test 9: Checking active mount options..."
if mount | grep -q "noatime"; then
    echo "✅ noatime is active on mounted filesystems"
else
    echo "⚠️  noatime not currently active (may require reboot)"
fi

# Test 10: Check swappiness setting
echo "📋 Test 10: Checking swappiness setting..."
current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "unknown")
if [[ "$current_swappiness" == "1" ]]; then
    echo "✅ Swappiness is optimally set to 1"
elif [[ "$current_swappiness" -le "10" ]]; then
    echo "✅ Swappiness is acceptably low: $current_swappiness"
else
    echo "⚠️  Swappiness is: $current_swappiness (may require reboot for sysctl changes)"
fi

echo ""
echo "🎯 Test Summary"
echo "==============="
echo "Run this script after applying eMMC optimizations to verify configuration."
echo "Some settings may require a reboot to take effect."
echo ""
echo "📊 To check current status:"
echo "  sudo systemctl status fstrim.timer"
echo "  sudo systemctl status emmc-health-check.timer"
echo "  cat /proc/sys/vm/swappiness"
echo "  mount | grep noatime"
echo ""
echo "🛠️  To run manual maintenance:"
echo "  sudo /usr/local/bin/emmc-maintenance.sh"