#!/usr/bin/env bash
#===============================================================================
# tires-install.sh - Install script for tar.gz package
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔════════════════════════════════════════╗"
echo "║  tires - Installation Script           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect installation prefix
PREFIX="${PREFIX:-/usr}"
BINDIR="${PREFIX}/bin"
LIBDIR="${PREFIX}/lib"
SYSCONFDIR="${SYSCONFDIR:-/etc}"
SYSTEMD_DIR="/lib/systemd/system"

echo "Installation paths:"
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

# Create directories
echo "📁 Creating directories..."
mkdir -p "$BINDIR"
mkdir -p "$LIBDIR"
mkdir -p "$SYSCONFDIR/tires"
mkdir -p "$SYSTEMD_DIR"

# Install binary
echo "📦 Installing binary..."
cp "$SCRIPT_DIR/tires" "$BINDIR/tires"
chmod +x "$BINDIR/tires"

# Install Mono.Unix library (REQUIRED for POSIX file operations)
echo "📦 Installing libMono.Unix.so..."
cp "$SCRIPT_DIR/libMono.Unix.so" "$LIBDIR/libMono.Unix.so"
chmod 644 "$LIBDIR/libMono.Unix.so"

# Update library cache
echo "🔄 Updating library cache..."
ldconfig

# Install config example
echo "📝 Installing configuration example..."
if [[ -f "$SCRIPT_DIR/storage.json" ]]; then
    cp "$SCRIPT_DIR/storage.json" "$SYSCONFDIR/tires/storage.json.example"
fi

# Install systemd files
echo "⚙️  Installing systemd files..."
if [[ -d "$SCRIPT_DIR/systemd" ]]; then
    cp "$SCRIPT_DIR/systemd/tires.service" "$SYSTEMD_DIR/" 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/tires.timer" "$SYSTEMD_DIR/" 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/tires-setup-timer.sh" "$BINDIR/" 2>/dev/null || true
    chmod +x "$BINDIR/tires-setup-timer.sh" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
fi

echo ""
echo -e "\033[0;32m✅ Installation completed!\033[0m"
echo ""
echo "Next steps:"
echo "  1. Create configuration:"
echo "     sudo cp $SYSCONFDIR/tires/storage.json.example $SYSCONFDIR/tires/storage.json"
echo "     sudo nano $SYSCONFDIR/tires/storage.json"
echo ""
echo "  2. Run manually:"
echo "     sudo tires $SYSCONFDIR/tires/storage.json"
echo ""
echo "  3. Or enable automatic timer:"
echo "     sudo tires-setup-timer.sh"
echo "     sudo systemctl enable --now tires.timer"
echo ""
