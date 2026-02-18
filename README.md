# Tires — Tiered Storage Manager

[![Tests](https://github.com/gailoks/tires/actions/workflows/tests.yml/badge.svg)](https://github.com/gailoks/tires/actions/workflows/tests.yml)
[![Build](https://github.com/gailoks/tires/actions/workflows/build.yml/badge.svg)](https://github.com/gailoks/tires/actions/workflows/build.yml)
[![License](https://img.shields.io/github/license/gailoks/tires)](LICENSE)

> **Automatically move files between storage tiers based on smart rules**

---

## What is Tires?

**Tires** automatically organizes files across multiple storage devices:
- **Large files** → slow/cheap storage (HDD)
- **Small files** → fast/expensive storage (SSD)  
- **Important folders** → excluded from movement

**Result:** Fast system without manual file management!

---

## Quick Start

### 1. Install

```bash
# Debian/Ubuntu
sudo dpkg -i tires_*.deb

# Fedora/RHEL
sudo rpm -ivh tires-*.rpm

# Any Linux
tar -xzf tires-*-linux-x64.tar.gz
sudo cp tires-*-linux-x64/tires /usr/local/bin/
```

### 2. Configure

Create `/etc/tires/storage.json`:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ]
}
```

### 3. Run

```bash
# Manual
sudo tires /etc/tires/storage.json

# Automatic (hourly)
sudo systemctl enable --now tires.timer
```

**📚 For detailed examples, see [examples/](examples/README.md)**

---

## Configuration

### Core Options

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "TemporaryPath": "tmp",
    "Tiers": [
        {
            "target": 90,
            "path": "/mnt/ssd",
            "MockCapacity": 1073741824
        }
    ],
    "FolderRules": [
        {
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        }
    ]
}
```

### Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `IterationLimit` | int | 20 | Max move iterations per run |
| `LogLevel` | string | "Information" | Debug, Information, Warning, Error |
| `TemporaryPath` | string | "tmp" | Temp folder during moves |
| `Tiers` | array | required | Storage tier definitions |
| `FolderRules` | array | null | Optional sorting/exclusion rules |

### Tier Options

| Option | Type | Description |
|--------|------|-------------|
| `target` | int | Fill percentage (90 = 90% max) |
| `path` | string | Absolute path to tier |
| `MockCapacity` | int | **Testing only** — mock capacity in bytes |

### FolderRules Options

| Option | Type | Description |
|--------|------|-------------|
| `PathPrefix` | string | Folder path to match |
| `Priority` | int | Higher = processed first |
| `RuleType` | string | `Size`, `Name`, `Time`, `Ignore` |
| `Reverse` | bool | Reverse sort order |
| `Pattern` | string | Pattern for Name rule |
| `TimeType` | string | `Access`, `Modify`, `Change` |

---

## Rules

### IgnoreRule — Exclude Folders

Files in matching folders are **never moved**:

```json
{"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"}
```

### SizeRule — Sort by Size

```json
{"PathPrefix": "videos", "Priority": 50, "RuleType": "Size", "Reverse": true}
```

- `Reverse: true` — Large files first (→ slower tier)
- `Reverse: false` — Small files first (→ faster tier)

### NameRule — Sort by Pattern

```json
{"PathPrefix": "media", "Priority": 30, "RuleType": "Name", "Pattern": ".mp4"}
```

### TimeRule — Sort by Time

```json
{"PathPrefix": "documents", "Priority": 20, "RuleType": "Time", "TimeType": "Modify"}
```

---

## Examples

### Quick Examples

**2-Tier (SSD + HDD):**
```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"},
        {"PathPrefix": "videos", "Priority": 50, "RuleType": "Size", "Reverse": true}
    ]
}
```

**3-Tier (NVMe + SATA + Archive):**
```json
{
    "Tiers": [
        {"target": 80, "path": "/mnt/nvme"},
        {"target": 90, "path": "/mnt/sata"},
        {"target": 100, "path": "/mnt/archive"}
    ]
}
```

**Testing with Mock Capacity:**
```json
{
    "Tiers": [
        {"target": 100, "path": "/tmp/hot", "MockCapacity": 2097152},
        {"target": 100, "path": "/tmp/cold", "MockCapacity": 10485760}
    ]
}
```

### 📚 Detailed Examples

See **[examples/README.md](examples/README.md)** for:
- Basic 2-tier setup with file distribution
- Excluding important folders (multiple rules)
- Sorting videos by size
- 3-tier workstation setup
- Pattern-based file sorting
- Time-based sorting
- Testing with MockCapacity
- Photo/video editor workflow

---

## Systemd Service

### Enable Automatic Runs

```bash
sudo cp packaging/systemd/*.service /lib/systemd/system/
sudo cp packaging/systemd/*.timer /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tires.timer
```

### Customize Schedule

Create `/etc/systemd/system/tires.timer.d/override.conf`:

```ini
[Timer]
OnCalendar=*-*-* 00/6:00:00  # Every 6 hours
Persistent=true
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart tires.timer
```

---

## Testing

```bash
# All tests (no sudo required!)
./Tests/tires-test-runner.sh

# List tests
./Tests/tires-test-runner.sh --list

# Specific tests
./Tests/tires-test-runner.sh default folders hardlinks
```

### Available Tests (12 total)

All tests run **without sudo** using `MockCapacity`:

| Test | Description |
|------|-------------|
| `default` | Basic file movement |
| `folders` | Nested directories |
| `hardlinks` | Hardlink preservation |
| `symlink` | Symlink preservation |
| `folder-rules/priority` | Rule priority |
| `folder-rules/name-rule` | Name-based sorting |
| `folder-rules/time-rule` | Time-based sorting |
| `ignore-rule/pattern` | Folder exclusion |
| `ignore-rule/size` | Folder exclusion |
| `bigfiles` | Mock capacity (4MB/8MB) |
| `capacity-limit` | Mock capacity (2MB/10MB) |
| `multi-tier` | 3-tier distribution |

---

## Troubleshooting

### Files Not Moving

```bash
# Check logs
journalctl -u tires.service -f

# Verify config
tires /etc/tires/storage.json

# Check paths exist
ls -la /mnt/ssd /mnt/hdd
```

### Permission Denied

```bash
sudo tires /etc/tires/storage.json
```

### Service Issues

```bash
sudo systemctl status tires.service tires.timer
sudo journalctl -u tires.service -n 50
```

---

## FAQ

**Q: Does Tires work without mergerfs?**  
A: Yes! Works with any folder structure.

**Q: Will Tires delete my files?**  
A: No, only moves between tiers.

**Q: Can I run manually?**  
A: Yes: `tires /path/to/config.json`

**Q: How often should it run?**  
A: Hourly default. Adjust via systemd timer.

**Q: What if a tier fills up?**  
A: Respects `target` percentage, stops when full.

**Q: Are permissions preserved?**  
A: Yes — permissions, ownership, timestamps.

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Program.cs (Entry Point)               │
├─────────────────────────────────────────┤
│  ConfigLoader  → Parse JSON config      │
│  StorageScanner → Scan tiers for files  │
│  StoragePlanner → Calculate distribution│
│  TierMover     → Execute moves          │
├─────────────────────────────────────────┤
│  Rules: Size, Name, Time, Ignore        │
└─────────────────────────────────────────┘
```

---

## License

ISC License — See [LICENSE](LICENSE) for details.

---

## Links

- [Examples](examples/README.md) — Detailed configuration examples
- [mergerfs](https://github.com/trapexit/mergerfs) — Union filesystem
- [GitHub Issues](https://github.com/gailoks/tires/issues) — Report bugs
- [Discussions](https://github.com/gailoks/tires/discussions) — Questions

---

# Русский

**Tires** — автоматическая организация файлов по уровням хранения.

## Быстрый старт

### 1. Установка

```bash
# Debian/Ubuntu
sudo dpkg -i tires_*.deb

# Fedora/RHEL  
sudo rpm -ivh tires-*.rpm

# Любой Linux
tar -xzf tires-*-linux-x64.tar.gz
sudo cp tires-*-linux-x64/tires /usr/local/bin/
```

### 2. Конфигурация

`/etc/tires/storage.json`:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ]
}
```

### 3. Запуск

```bash
# Вручную
sudo tires /etc/tires/storage.json

# Автоматически (каждый час)
sudo systemctl enable --now tires.timer
```

## Примеры

Подробные примеры на английском: **[examples/README.md](examples/README.md)**

### Краткие примеры

**2 уровня (SSD + HDD):**
```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"},
        {"PathPrefix": "videos", "Priority": 50, "RuleType": "Size", "Reverse": true}
    ]
}
```

**Тестирование с MockCapacity:**
```json
{
    "Tiers": [
        {"target": 100, "path": "/tmp/hot", "MockCapacity": 2097152},
        {"target": 100, "path": "/tmp/cold", "MockCapacity": 10485760}
    ]
}
```

## Правила

| Правило | Описание |
|---------|----------|
| `Ignore` | Исключить папки из перемещения |
| `Size` | Сортировка по размеру |
| `Name` | Сортировка по паттерну имени |
| `Time` | Сортировка по времени |

## Тесты

Все 12 тестов работают **без sudo**:

```bash
./Tests/tires-test-runner.sh
```

---

**Полная документация выше ↑** | **[Примеры](examples/README.md)**
