#!/bin/bash
# Tires installation script with Mono.Unix dependency

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr}"

echo "🚗 Installing Tires..."

# Create directories
sudo mkdir -p "$INSTALL_PREFIX/bin"
sudo mkdir -p "$INSTALL_PREFIX/lib"
sudo mkdir -p "$INSTALL_PREFIX/share/doc/tires"
sudo mkdir -p "/etc/tires"
sudo mkdir -p "/lib/systemd/system"

# Copy binary
echo "📦 Copying binary..."
sudo cp "$SCRIPT_DIR/tires" "$INSTALL_PREFIX/bin/"
sudo chmod +x "$INSTALL_PREFIX/bin/tires"

# Copy Mono.Unix library
echo "📦 Copying Mono.Unix library..."
if [ -f "$SCRIPT_DIR/libMono.Unix.so" ]; then
    sudo cp "$SCRIPT_DIR/libMono.Unix.so" "$INSTALL_PREFIX/lib/"
    sudo ldconfig 2>/dev/null || true
    echo "✅ Mono.Unix installed"
fi

# Copy docs
echo "📦 Copying documentation..."
sudo cp "$SCRIPT_DIR/README.md" "$INSTALL_PREFIX/share/doc/tires/" 2>/dev/null || true
sudo cp "$SCRIPT_DIR/storage.json" "$INSTALL_PREFIX/share/doc/tires/storage.json.example" 2>/dev/null || true

# Copy systemd files
echo "📦 Copying systemd files..."
sudo cp "$SCRIPT_DIR/systemd/tires.service" "/lib/systemd/system/" 2>/dev/null || true
sudo cp "$SCRIPT_DIR/systemd/tires.timer" "/lib/systemd/system/" 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

# Verify installation
echo ""
echo "✅ Tires installed successfully!"
echo ""
echo "Usage:"
echo "  tires /path/to/storage.json"
echo ""
echo "Enable automatic runs:"
echo "  sudo systemctl enable --now tires.timer"
echo ""
echo "Check status:"
echo "  systemctl status tires.timer"
echo ""
