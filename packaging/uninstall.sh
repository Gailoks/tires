#!/usr/bin/env bash
#===============================================================================
# tires-uninstall.sh - Uninstall script for tar.gz package
#===============================================================================

set -euo pipefail

echo "╔════════════════════════════════════════╗"
echo "║  tires - Uninstallation Script         ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect installation prefix
PREFIX="${PREFIX:-/usr}"
BINDIR="${PREFIX}/bin"
LIBDIR="${PREFIX}/lib"
SYSCONFDIR="${SYSCONFDIR:-/etc}"
SYSTEMD_DIR="/lib/systemd/system"

echo "Removing files from:"
echo "  Binary:       $BINDIR"
echo "  Library:      $LIBDIR"
echo "  Config:       $SYSCONFDIR/tires"
echo "  Systemd:      $SYSTEMD_DIR"
echo ""

# Check for root/sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m❌ This script must be run as root (or with sudo)\033[0m"
    exit 1
fi

# Stop and disable systemd timer
echo "🛑 Stopping systemd timer..."
systemctl stop tires.timer 2>/dev/null || true
systemctl disable tires.timer 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

# Remove files
echo "🗑️  Removing files..."
rm -f "$BINDIR/tires"
rm -f "$BINDIR/tires-setup-timer.sh"
rm -f "$LIBDIR/libMono.Unix.so"
rm -f "$SYSTEMD_DIR/tires.service"
rm -f "$SYSTEMD_DIR/tires.timer"
rm -rf "$SYSCONFDIR/tires"

# Update library cache
echo "🔄 Updating library cache..."
ldconfig

echo ""
echo -e "\033[0;32m✅ Uninstallation completed!\033[0m"
