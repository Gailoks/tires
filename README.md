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

**All packages include `libMono.Unix.so` — no need to install Mono separately!**

```bash
# Debian/Ubuntu
sudo dpkg -i tires_*.deb
# libMono.Unix.so is installed to /usr/lib/
# ldconfig is called automatically

# Fedora/RHEL
sudo rpm -ivh tires-*.rpm
# libMono.Unix.so is installed to /usr/lib/

# Any Linux (manual)
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64
sudo cp tires /usr/local/bin/
sudo cp libMono.Unix.so /usr/lib/
sudo ldconfig
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

**🇷🇺 [Русские примеры](examples/README.ru.md)**

---

## Configuration

### Core Options

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "TemporaryPath": "tmp",
    "RunInterval": "hourly",
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
| `RunInterval` | string | "hourly" | How often to run: `minutely`, `hourly`, `daily`, `weekly`, `monthly`, or systemd calendar format |
| `ProcessPriority` | int | 2 | Process priority: -20 (highest) to 19 (lowest), default 2 (Idle) |
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
| `Reverse` | bool | Reverse sort order (see Rules section) |
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

Sorts files by their size. Files are assigned to tiers based on sort order — **first files go to faster tier (SSD)**.

```json
{"PathPrefix": "videos", "Priority": 50, "RuleType": "Size", "Reverse": true}
```

| Reverse | Sort Order | Files Go to SSD | Files Go to HDD |
|---------|-----------|-----------------|-----------------|
| `false` (default) | Small → Large | **Small files** | Large files |
| `true` | Large → Small | **Large files** | Small files |

**Examples:**

- `"Reverse": false` — Small files processed first → **stay on SSD** (1MB, 5MB), large files → HDD (100MB, 1GB)
- `"Reverse": true` — Large files processed first → **stay on SSD** (1GB, 500MB), small files → HDD (10MB, 5MB)

### NameRule — Sort by Pattern

Sorts files by whether they match a pattern. Matching files get higher score (go to slower tier).

```json
{"PathPrefix": "media", "Priority": 30, "RuleType": "Name", "Pattern": ".mp4"}
```

| Reverse | Match Score | Non-Match Score | Files Go to SSD | Files Go to HDD |
|---------|-------------|-----------------|-----------------|-----------------|
| `false` (default) | 1 | 0 | **Non-matching** | Matching |
| `true` | -1 | 0 | **Matching** | Non-matching |

**Examples:**

- `"Reverse": false` — Non-matching files (score 0) → **SSD**, matching files (score 1) → HDD
- `"Reverse": true` — Matching files (score -1) → **SSD**, non-matching files (score 0) → HDD

### TimeRule — Sort by Time

Sorts files by timestamp. Newer files have higher score (go to slower tier).

```json
{"PathPrefix": "documents", "Priority": 20, "RuleType": "Time", "TimeType": "Modify"}
```

| TimeType | Description |
|----------|-------------|
| `Access` | Last access time |
| `Modify` | Last modification time |
| `Change` | Last metadata change |

| Reverse | Sort Order | Files Go to SSD | Files Go to HDD |
|---------|-----------|-----------------|-----------------|
| `false` (default) | Old → New | **Old files** | New files |
| `true` | New → Old | **New files** | Old files |

**Examples:**

- `"Reverse": false` — Old files (low timestamp) → **SSD**, new files (high timestamp) → HDD
- `"Reverse": true` — New files (low negative score) → **SSD**, old files (high negative score) → HDD

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

### Configure Run Interval

Edit `/etc/tires/storage.json`:

```json
{
    "RunInterval": "daily"
}
```

Supported values:
- `minutely` — Every minute
- `hourly` — Every hour (default)
- `daily` — Every day at midnight
- `weekly` — Every Monday at midnight
- `monthly` — 1st day of each month
- Custom systemd calendar format (e.g., `*-*-* 02:00:00` for daily at 2 AM)

Then apply the configuration:

```bash
sudo ./packaging/systemd/configure-timer.sh /etc/tires/storage.json
```

### Customize Schedule Manually

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

**Все пакеты включают `libMono.Unix.so` — не нужно устанавливать Mono отдельно!**

```bash
# Debian/Ubuntu
sudo dpkg -i tires_*.deb
# libMono.Unix.so устанавливается в /usr/lib/
# ldconfig вызывается автоматически

# Fedora/RHEL
sudo rpm -ivh tires-*.rpm
# libMono.Unix.so устанавливается в /usr/lib/

# Любой Linux (вручную)
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64
sudo cp tires /usr/local/bin/
sudo cp libMono.Unix.so /usr/lib/
sudo ldconfig
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

Подробные примеры:
- **[🇬🇧 English](examples/README.md)**
- **[🇷🇺 Русский](examples/README.ru.md)**

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

### IgnoreRule — Исключить папки

Файлы в указанных папках **никогда не перемещаются**:

```json
{"PathPrefix": "important", "Priority": 100, "RuleType": "Ignore"}
```

### SizeRule — Сортировка по размеру

| Reverse | Порядок | Файлы на SSD | Файлы на HDD |
|---------|---------|--------------|--------------|
| `false` (по умолчанию) | Малые → Большие | **Малые файлы** | Большие файлы |
| `true` | Большие → Малые | **Большие файлы** | Малые файлы |

**Примеры:**

- `"Reverse": false` — Малые файлы сначала → **остаются на SSD** (1МБ, 5МБ), большие → HDD (100МБ, 1ГБ)
- `"Reverse": true` — Большие файлы сначала → **остаются на SSD** (1ГБ, 500МБ), малые → HDD (10МБ, 5МБ)

### NameRule — Сортировка по паттерну

Сортирует файлы по совпадению с паттерном. Совпадающие файлы получают высокий балл (идут на медленный диск).

```json
{"PathPrefix": "media", "Priority": 30, "RuleType": "Name", "Pattern": ".mp4"}
```

| Reverse | Балл совпадения | Балл несовпадения | Файлы на SSD | Файлы на HDD |
|---------|-----------------|-------------------|--------------|--------------|
| `false` (по умолчанию) | 1 | 0 | **Несовпадающие** | Совпадающие |
| `true` | -1 | 0 | **Совпадающие** | Несовпадающие |

**Примеры:**

- `"Reverse": false` — Несовпадающие файлы (балл 0) → **SSD**, совпадающие (балл 1) → HDD
- `"Reverse": true` — Совпадающие файлы (балл -1) → **SSD**, несовпадающие (балл 0) → HDD

### TimeRule — Сортировка по времени

Сортирует файлы по временной метке. Новые файлы имеют высокий балл (идут на медленный диск).

```json
{"PathPrefix": "documents", "Priority": 20, "RuleType": "Time", "TimeType": "Modify"}
```

| TimeType | Описание |
|----------|----------|
| `Access` | Время последнего доступа |
| `Modify` | Время последнего изменения |
| `Change` | Время последнего изменения метаданных |

| Reverse | Порядок | Файлы на SSD | Файлы на HDD |
|---------|---------|--------------|--------------|
| `false` (по умолчанию) | Старые → Новые | **Старые файлы** | Новые файлы |
| `true` | Новые → Старые | **Новые файлы** | Старые файлы |

**Примеры:**

- `"Reverse": false` — Старые файлы (низкая метка) → **SSD**, новые (высокая метка) → HDD
- `"Reverse": true` — Новые файлы (низкий отрицательный балл) → **SSD**, старые (высокий отрицательный балл) → HDD

## Тесты

Все 12 тестов работают **без sudo**:

```bash
./Tests/tires-test-runner.sh
```

---

**Полная документация выше ↑** | **[Примеры](examples/README.ru.md)** | **[Examples](examples/README.md)**
