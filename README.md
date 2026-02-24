# Tires — Tiered Storage Manager

[![Build & Release](https://github.com/gailoks/tires/actions/workflows/build.yml/badge.svg)](https://github.com/gailoks/tires/actions/workflows/build.yml)
[![License](https://img.shields.io/github/license/gailoks/tires)](LICENSE)
[![Release](https://img.shields.io/github/v/release/gailoks/tires?label=latest%20release)](https://github.com/gailoks/tires/releases/latest)

> **Automatically move files between storage tiers based on smart rules**

---

## 🚀 Quick Start

### Install

**From .deb (Debian/Ubuntu):**
```bash
sudo dpkg -i tires_*.deb
sudo apt-get install -f  # Install dependencies if needed
```

**From .rpm (Fedora/RHEL):**
```bash
sudo rpm -ivh tires-*.rpm
```

**From tar.gz (Manual):**
```bash
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64
sudo ./install.sh
```

All packages include **libMono.Unix.so** — no separate Mono installation needed!

### Configure

Create `/etc/tires/storage.json`:

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "RunInterval": "hourly",
    "ProcessPriority": 2,
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"}
    ]
}
```

### Run

```bash
# Manual
sudo tires /etc/tires/storage.json

# Automatic (hourly)
sudo systemctl enable --now tires.timer
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[📖 Full Documentation](docs/README.md)** | Complete guide with all options |
| **[📝 Examples](examples/README.md)** | Configuration examples |
| **[🇷🇺 Русский](docs/README.ru.md)** | Документация на русском |
| **[🧪 Tests](docs/TESTS.md)** | Test suite documentation |

---

## 🔧 Key Features

- **Automatic tiering** — Move files between SSD/HDD/archive based on smart rules
- **Smart rules** — Size, name, time-based sorting with priority system
- **Exclude folders** — Protect important data with IgnoreRule
- **Systemd integration** — Automatic scheduled runs with configurable intervals
- **No external dependencies** — Single binary with libMono.Unix.so bundled
- **Native AOT** — Optional Native AOT compilation for faster startup
- **Security hardening** — Systemd service with NoNewPrivileges, ProtectSystem, ProtectHome
- **File preservation** — Preserves permissions, ownership, timestamps, and hardlinks
- **Mock capacity testing** — Test without actual disk limits using MockCapacity

---

## 📦 Packages

| Package | Description |
|---------|-------------|
| `.deb` | Debian/Ubuntu (amd64) |
| `.rpm` | Fedora/RHEL/Rocky (x86_64) |
| `.tar.gz` | Any Linux (manual install) |

All packages include `libMono.Unix.so` — no separate Mono installation needed!

---

## 🧪 Testing

```bash
# Run all tests (no sudo required)
./Tests/tires-test-runner.sh

# List available tests
./Tests/tires-test-runner.sh --list

# Specific tests
./Tests/tires-test-runner.sh default folders hardlinks
```

Tests use `MockCapacity` to simulate tier sizes — **no root privileges or actual disk partitions required!**

See **[🧪 Tests Documentation](docs/TESTS.md)** for details.

---

## ❓ FAQ

**Q: Does Tires work without mergerfs?**
A: Yes! Works with any folder structure.

**Q: Will Tires delete my files?**
A: No, only moves between tiers.

**Q: How often does it run?**
A: Hourly by default. Configure via `RunInterval` in storage.json or customize the systemd timer.

**Q: Are permissions preserved?**
A: Yes — permissions, ownership, timestamps, and hardlinks are preserved during moves.

**Q: Do I need to install Mono?**
A: No! libMono.Unix.so is bundled in all packages.

**Q: Can I test without affecting real files?**
A: Yes! Use `MockCapacity` in test configurations to simulate tier sizes.

---

## 🔗 Links

- **[GitHub Issues](https://github.com/gailoks/tires/issues)** — Report bugs
- **[Discussions](https://github.com/gailoks/tires/discussions)** — Questions
- **[Releases](https://github.com/gailoks/tires/releases)** — Downloads

---

## 📄 License

ISC License — See [LICENSE](LICENSE) for details.

---

## 🇷🇺 Русский

**Tires** — автоматическая организация файлов по уровням хранения.

### Быстрый старт

```bash
# Установка
sudo dpkg -i tires_*.deb  # Debian/Ubuntu
sudo rpm -ivh tires-*.rpm # Fedora/RHEL
tar -xzf tires-*-linux-x64.tar.gz && cd tires-*-linux-x64 && sudo ./install.sh  # Manual

# Конфигурация
sudo nano /etc/tires/storage.json

# Запуск
sudo tires /etc/tires/storage.json
```

**[📖 Документация на русском](docs/README.ru.md)** | **[📝 Примеры](examples/README.ru.md)** | **[🧪 Тесты](docs/TESTS.md)**
