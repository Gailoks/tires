# Tires Installation Guide

## Quick Install (Manual)

### 1. Install Mono.Unix dependency

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install -y libmono-2.0-1 libmono-posix-4.0-1cilib
```

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install mono-core mono-posix
```

### 2. Install Tires

**From tar.gz:**
```bash
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64

# Copy files
sudo cp tires /usr/local/bin/
sudo cp libMono.Unix.so /usr/lib/ 2>/dev/null || true
sudo ldconfig 2>/dev/null || true

# Optional: Install systemd files
sudo cp systemd/*.service /lib/systemd/system/
sudo cp systemd/*.timer /lib/systemd/system/
sudo cp systemd/tires-setup-timer.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/tires-setup-timer.sh
sudo systemctl daemon-reload
```

**From .deb:**
```bash
sudo dpkg -i tires_*.deb
sudo apt-get install -f  # Install dependencies
```

**From .rpm:**
```bash
sudo rpm -ivh tires-*.rpm
```

### 3. Configure

```bash
# Create config directory
sudo mkdir -p /etc/tires

# Create configuration
sudo nano /etc/tires/storage.json

# Example configuration
sudo cp /usr/share/doc/tires/storage.json.example /etc/tires/storage.json
```

**Configure timer schedule:**

The timer schedule is controlled by the `RunInterval` field in `/etc/tires/storage.json`:

```json
{
  "RunInterval": "hourly",  // minutely, hourly, daily, weekly, monthly
  ...
}
```

Or use systemd calendar format for custom schedules:
- `"*-*-* 02:00:00"` - Daily at 2 AM
- `"Mon..Fri *-*-* 09:00:00"` - Weekdays at 9 AM
- `"*-*-* 00:00:00"` - Daily at midnight

After editing the config, run:
```bash
sudo tires-setup-timer.sh
```

### 4. Run

**Manual:**
```bash
sudo tires /etc/tires/storage.json
```

**Automatic (systemd):**
```bash
sudo systemctl enable --now tires.timer
sudo systemctl status tires.timer
```

---

## Build from Source

### Requirements

- .NET 8 SDK
- Git

### Build

```bash
# Clone repository
git clone https://github.com/gailoks/tires.git
cd tires

# Build
dotnet build -c Release

# Build Native AOT (optional, larger binary but faster)
dotnet publish -c Release -r linux-x64 --self-contained -p:PublishAot=true -o ./publish

# Run tests
./Tests/tires-test-runner.sh
```

### Create Packages

```bash
# Build all packages
./build.sh

# Output in ./artifacts/
# - tires-*.tar.gz
# - tires_*.deb
# - tires-*.rpm
```

---

## Troubleshooting

### Mono.Unix not found

**Error:**
```
System.DllNotFoundException: Unable to load shared library 'Mono.Unix'
```

**Solution:**
```bash
# Install Mono packages
sudo apt-get install -y libmono-2.0-1 libmono-posix-4.0-1cilib

# Or copy from build
sudo cp /path/to/tires/libMono.Unix.so /usr/lib/
sudo ldconfig
```

### Permission denied

**Error:**
```
Permission denied /mnt/hot
```

**Solution:**
```bash
# Run as root
sudo tires /etc/tires/storage.json

# Or check permissions
ls -la /mnt/hot
```

### No files found

**Error:**
```
Total files found: 0
```

**Solution:**
1. Check files exist: `find /mnt/hot -type f | wc -l`
2. Check permissions: `ls -la /mnt/hot/`
3. Enable debug logging in config: `"LogLevel": "Debug"`

---

## Uninstall

**Manual:**
```bash
sudo rm /usr/local/bin/tires
sudo rm /usr/lib/libMono.Unix.so
sudo rm /lib/systemd/system/tires.service
sudo rm /lib/systemd/system/tires.timer
sudo systemctl daemon-reload
sudo rm -rf /etc/tires
```

**From .deb:**
```bash
sudo apt-get remove tires
```

**From .rpm:**
```bash
sudo rpm -e tires
```
