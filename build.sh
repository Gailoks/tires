#!/usr/bin/env bash
#===============================================================================
# tires-build.sh - Build script for tires
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION="${VERSION:-1.0.0}"
OUTPUT_DIR="$SCRIPT_DIR/artifacts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  tires - Build Script                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Clean artifacts
echo -e "${YELLOW}🧹 Cleaning artifacts...${NC}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build native AOT binary
echo -e "${YELLOW}🔨 Building native AOT binary...${NC}"
dotnet publish -c Release -r linux-x64 --self-contained -p:PublishAot=true -o "$OUTPUT_DIR/linux-x64"

if [[ -f "$OUTPUT_DIR/linux-x64/tires" ]]; then
    echo -e "${GREEN}✅ Native AOT binary built successfully${NC}"
    echo "   Size: $(du -h "$OUTPUT_DIR/linux-x64/tires" | cut -f1)"
else
    echo -e "${RED}❌ Failed to build native AOT binary${NC}"
    exit 1
fi

# Verify libMono.Unix.so exists
if [[ ! -f "$OUTPUT_DIR/linux-x64/libMono.Unix.so" ]]; then
    echo -e "${RED}❌ libMono.Unix.so not found!${NC}"
    echo "   This is required for Tires to work."
    exit 1
fi
echo -e "${GREEN}✅ libMono.Unix.so found${NC}"

# Create tar.gz package
echo -e "${YELLOW}📦 Creating tar.gz package...${NC}"
PACKAGE_DIR="$OUTPUT_DIR/tires-$VERSION-linux-x64"
mkdir -p "$PACKAGE_DIR"

cp "$OUTPUT_DIR/linux-x64/tires" "$PACKAGE_DIR/"
cp "$OUTPUT_DIR/linux-x64/libMono.Unix.so" "$PACKAGE_DIR/"
cp "$SCRIPT_DIR/README.md" "$PACKAGE_DIR/"
cp "$SCRIPT_DIR/storage.json" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/INSTALL.md" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/install.sh" "$PACKAGE_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/uninstall.sh" "$PACKAGE_DIR/" 2>/dev/null || true
chmod +x "$PACKAGE_DIR/install.sh" "$PACKAGE_DIR/uninstall.sh" 2>/dev/null || true
mkdir -p "$PACKAGE_DIR/systemd"
cp "$SCRIPT_DIR/packaging/systemd/"*.service "$PACKAGE_DIR/systemd/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/systemd/"*.timer "$PACKAGE_DIR/systemd/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/systemd/tires-setup-timer.sh" "$PACKAGE_DIR/systemd/" 2>/dev/null || true

cd "$OUTPUT_DIR"
tar -czf "tires-$VERSION-linux-x64.tar.gz" "tires-$VERSION-linux-x64"
cd "$SCRIPT_DIR"

echo -e "${GREEN}✅ tar.gz package created: $OUTPUT_DIR/tires-$VERSION-linux-x64.tar.gz${NC}"

# Create .deb package using Docker
echo -e "${YELLOW}📦 Creating .deb package...${NC}"
DEB_BUILD_DIR="$OUTPUT_DIR/deb-build"
DEB_PACKAGE_DIR="$DEB_BUILD_DIR/tires_$VERSION-1_amd64"

mkdir -p "$DEB_PACKAGE_DIR/DEBIAN"
mkdir -p "$DEB_PACKAGE_DIR/usr/bin"
mkdir -p "$DEB_PACKAGE_DIR/usr/lib"
mkdir -p "$DEB_PACKAGE_DIR/usr/share/tires"
mkdir -p "$DEB_PACKAGE_DIR/etc/tires"
mkdir -p "$DEB_PACKAGE_DIR/lib/systemd/system"

# Copy binary
cp "$OUTPUT_DIR/linux-x64/tires" "$DEB_PACKAGE_DIR/usr/bin/tires"
chmod +x "$DEB_PACKAGE_DIR/usr/bin/tires"

# Copy Mono.Unix library (REQUIRED!)
cp "$OUTPUT_DIR/linux-x64/libMono.Unix.so" "$DEB_PACKAGE_DIR/usr/lib/"

# Copy config example
cp "$SCRIPT_DIR/storage.json" "$DEB_PACKAGE_DIR/etc/tires/storage.json.example" 2>/dev/null || true

# Copy systemd files
cp "$SCRIPT_DIR/packaging/systemd/tires.service" "$DEB_PACKAGE_DIR/lib/systemd/system/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/systemd/tires.timer" "$DEB_PACKAGE_DIR/lib/systemd/system/" 2>/dev/null || true
cp "$SCRIPT_DIR/packaging/systemd/tires-setup-timer.sh" "$DEB_PACKAGE_DIR/usr/bin/" 2>/dev/null || true
chmod +x "$DEB_PACKAGE_DIR/usr/bin/tires-setup-timer.sh" 2>/dev/null || true

# Create control file
cat > "$DEB_PACKAGE_DIR/DEBIAN/control" << EOF
Package: tires
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libc6 (>= 2.31)
Maintainer: Tires Contributors
Description: Tiered Storage Manager for mergerfs
 Tires is a tiered storage manager that automatically moves files
 between storage tiers based on configurable rules.
 .
 Includes libMono.Unix.so for POSIX compatibility.
EOF

# Create postinst script
cat > "$DEB_PACKAGE_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
mkdir -p /etc/tires
# Update library cache
ldconfig 2>/dev/null || true
# Reload systemd if available
if command -v systemctl &> /dev/null; then
    systemctl daemon-reload || true
fi
EOF
chmod +x "$DEB_PACKAGE_DIR/DEBIAN/postinst"

# Create postrm script (cleanup on uninstall)
cat > "$DEB_PACKAGE_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    ldconfig 2>/dev/null || true
fi
EOF
chmod +x "$DEB_PACKAGE_DIR/DEBIAN/postrm"

# Build .deb using Docker if dpkg-deb not available locally
if command -v dpkg-deb &> /dev/null; then
    cd "$DEB_BUILD_DIR"
    dpkg-deb --build "tires_$VERSION-1_amd64"
    cp "tires_$VERSION-1_amd64.deb" "$OUTPUT_DIR/"
    cd "$SCRIPT_DIR"
else
    # Use Docker to build .deb
    docker run --rm -v "$DEB_BUILD_DIR:/build" -w /build ubuntu:22.04 bash -c "
        apt-get update && apt-get install -y dpkg
        dpkg-deb --build 'tires_$VERSION-1_amd64'
    "
    cp "$DEB_BUILD_DIR/tires_$VERSION-1_amd64.deb" "$OUTPUT_DIR/"
fi

echo -e "${GREEN}✅ .deb package created: $OUTPUT_DIR/tires_$VERSION-1_amd64.deb${NC}"

# Create .rpm package using Docker
echo -e "${YELLOW}📦 Creating .rpm package...${NC}"
RPM_BUILD_DIR="$OUTPUT_DIR/rpm-build"
mkdir -p "$RPM_BUILD_DIR/SPECS"
mkdir -p "$RPM_BUILD_DIR/SOURCES"
mkdir -p "$RPM_BUILD_DIR/BUILD"
mkdir -p "$RPM_BUILD_DIR/RPMS"
mkdir -p "$RPM_BUILD_DIR/SRPMS"

# Create source tarball
mkdir -p "$RPM_BUILD_DIR/SOURCES/tires-$VERSION"
cp -r "$OUTPUT_DIR/linux-x64/"* "$RPM_BUILD_DIR/SOURCES/tires-$VERSION/"
cp "$SCRIPT_DIR/README.md" "$RPM_BUILD_DIR/SOURCES/tires-$VERSION/"
cp "$SCRIPT_DIR/storage.json" "$RPM_BUILD_DIR/SOURCES/tires-$VERSION/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/packaging/systemd" "$RPM_BUILD_DIR/SOURCES/tires-$VERSION/" 2>/dev/null || true
tar -czf "$RPM_BUILD_DIR/SOURCES/tires-$VERSION.tar.gz" -C "$RPM_BUILD_DIR/SOURCES" "tires-$VERSION"
rm -rf "$RPM_BUILD_DIR/SOURCES/tires-$VERSION"

# Create spec file
cat > "$RPM_BUILD_DIR/SPECS/tires.spec" << EOF
Name: tires
Version: $VERSION
Release: 1%{?dist}
Summary: Tiered Storage Manager for mergerfs
License: MIT
URL: https://github.com/gailoks/tires
Source0: %{name}-%{version}.tar.gz
BuildArch: x86_64
Requires: glibc >= 2.31

%description
Tires is a tiered storage manager that automatically moves files
between storage tiers based on configurable rules.

Includes libMono.Unix.so for POSIX compatibility.

%prep
%setup -q

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/lib
mkdir -p %{buildroot}/etc/tires
mkdir -p %{buildroot}/lib/systemd/system

cp tires %{buildroot}/usr/bin/
cp libMono.Unix.so %{buildroot}/usr/lib/
cp storage.json %{buildroot}/etc/tires/storage.json.example
cp systemd/tires.service %{buildroot}/lib/systemd/system/
cp systemd/tires.timer %{buildroot}/lib/systemd/system/
cp systemd/tires-setup-timer.sh %{buildroot}/usr/bin/
chmod +x %{buildroot}/usr/bin/tires-setup-timer.sh

%post
ldconfig || :
systemctl daemon-reload || :

%postun
ldconfig || :
if [ \$1 -eq 1 ]; then
    systemctl try-restart tires.timer || :
fi

%preun
if [ \$1 -eq 0 ]; then
    systemctl stop tires.timer || :
    systemctl disable tires.timer || :
fi

%files
/usr/bin/tires
/usr/bin/tires-setup-timer.sh
/usr/lib/libMono.Unix.so
/etc/tires/storage.json.example
/lib/systemd/system/tires.service
/lib/systemd/system/tires.timer
EOF

# Build RPM using Docker if rpmbuild not available locally
if command -v rpmbuild &> /dev/null; then
    rpmbuild --define "_topdir $RPM_BUILD_DIR" -bb "$RPM_BUILD_DIR/SPECS/tires.spec"
else
    # Use Docker to build RPM (using RockyLinux as CentOS 7 is EOL)
    docker run --rm -v "$RPM_BUILD_DIR:/build" -w /build rockylinux:9 bash -c "
        dnf install -y rpm-build
        rpmbuild --define '_topdir /build' -bb /build/SPECS/tires.spec
    "
fi

# Copy RPM to artifacts
find "$RPM_BUILD_DIR/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;

echo -e "${GREEN}✅ .rpm package created: $OUTPUT_DIR/$(find "$RPM_BUILD_DIR/RPMS" -name '*.rpm' -printf '%f\n' | head -1)${NC}"

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  Build completed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "Artifacts in: ${BLUE}$OUTPUT_DIR${NC}"
ls -lh "$OUTPUT_DIR"/*.tar.gz "$OUTPUT_DIR"/*.deb "$OUTPUT_DIR"/*.rpm 2>/dev/null || true
