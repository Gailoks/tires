# Tires Installation Guide

## Quick Install (Manual)

### From tar.gz (Recommended)

```bash
# Extract archive
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64

# Run installer (requires root)
sudo ./install.sh
```

The installer will:
- Copy binary to `/usr/bin/tires`
- Copy libMono.Unix.so to `/usr/lib/`
- Run `ldconfig` to update library cache
- Install systemd files (optional)

### From .deb (Debian/Ubuntu)

```bash
sudo dpkg -i tires_*.deb
sudo apt-get install -f  # Install dependencies if needed
```

The package includes libMono.Unix.so and automatically runs `ldconfig`.

### From .rpm (RHEL/CentOS/Fedora)

```bash
sudo rpm -ivh tires-*.rpm
```

The package includes libMono.Unix.so and automatically runs `ldconfig`.

### Configure

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

**From tar.gz:**
```bash
cd tires-*-linux-x64
sudo ./uninstall.sh
```

**From .deb:**
```bash
sudo apt-get remove tires
```

**From .rpm:**
```bash
sudo rpm -e tires
```
