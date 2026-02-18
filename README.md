# Tires — Tiered Storage Manager

[![Tests](https://github.com/gailoks/tires/actions/workflows/tests.yml/badge.svg)](https://github.com/gailoks/tires/actions/workflows/tests.yml)
[![Build](https://github.com/gailoks/tires/actions/workflows/build.yml/badge.svg)](https://github.com/gailoks/tires/actions/workflows/build.yml)
[![License](https://img.shields.io/github/license/gailoks/tires)](LICENSE)

> **Automatically move files between storage tiers based on smart rules**

---

## What is Tires?

**Tires** is a tool that automatically organizes your files across multiple storage devices (tiers) based on rules you define.

### Why would I need this?

Imagine you have:
- A **fast SSD** (expensive, limited space)
- A **slow HDD** (cheap, lots of space)

Tires automatically:
- Moves **large files** (videos, archives) to the slow HDD
- Keeps **small files** (documents, configs) on the fast SSD
- **Excludes** important folders from any movement

**Result:** Your system stays fast without manual file management!

### Real-World Use Cases

| Scenario | Hot Tier (Fast) | Cold Tier (Slow) | Benefit |
|----------|-----------------|------------------|---------|
| Home Server | SSD 500GB | HDD 4TB | Fast system, bulk storage for media |
| Photo Editor | NVMe 1TB | HDD 8TB | Current projects fast, archives cheap |
| Developer | SSD 512GB | NAS | Code fast, backups on NAS |
| Media Server | SSD 100GB | HDD 10TB | Metadata fast, videos on HDD |

---

## Quick Start

### 1. Install

**From .deb (Debian/Ubuntu):**
```bash
sudo dpkg -i tires_*.deb
sudo apt-get install -f
```

**From .rpm (Fedora/RHEL):**
```bash
sudo rpm -ivh tires-*.rpm
```

**From tar.gz (Any Linux):**
```bash
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64
sudo cp tires /usr/local/bin/
```

### 2. Create Configuration

Create `/etc/tires/storage.json`:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/fast-ssd"},
        {"target": 100, "path": "/mnt/slow-hdd"}
    ]
}
```

### 3. Run

**Manual run:**
```bash
sudo tires /etc/tires/storage.json
```

**Or enable systemd service:**
```bash
sudo systemctl enable tires.timer
sudo systemctl start tires.timer
```

That's it! Tires will now automatically organize your files every hour.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        Tires Workflow                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SCAN          2. ANALYZE         3. MOVE                    │
│                                                                 │
│  ┌─────────┐     ┌────────────┐      ┌──────────┐               │
│  │ /mnt/   │     │ Apply      │      │ Move     │               │
│  │ hot/    │────▶│ Rules      │─────▶│ Files    │               │
│  │ /mnt/   │     │ Sort       │      │ Between  │               │
│  │ cold/   │     │ Prioritize │      │ Tiers    │               │
│  └─────────┘     └────────────┘      └──────────┘               │
│                                                                 │
│  Every hour (or manual run)                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### File Flow Example

```
Before Tires:                          After Tires:

/mnt/fast-ssd/                         /mnt/fast-ssd/
├── small.txt (5KB)                    ├── small.txt (5KB)      ← stays
├── config.json (2KB)                  ├── config.json (2KB)    ← stays
└── video.mp4 (2GB) ← too big!         └── doc.pdf (100KB)      ← moved up

/mnt/slow-hdd/                         /mnt/slow-hdd/
├── doc.pdf (100KB) ← should move      ├── video.mp4 (2GB)      ← moved down
└── archive.zip (500MB)                └── archive.zip (500MB)
```

---

## Configuration Guide

### Basic Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ]
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `IterationLimit` | number | 20 | Max move operations per run |
| `LogLevel` | string | "Information" | Debug, Information, Warning, Error |
| `TemporaryPath` | string | "tmp" | Temp folder name during moves |
| `Tiers` | array | required | List of storage locations |

### Tier Configuration

| Option | Type | Description |
|--------|------|-------------|
| `target` | number | Fill percentage (90 = 90% full max) |
| `path` | string | Absolute path to storage |

---

## Advanced Features

### 1. Exclude Folders (IgnoreRule)

Keep important files in place:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
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

Files in `/mnt/*/important/` will **never be moved**.

### 2. Sort by Size

Move large files to slow storage:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "videos",
            "Priority": 50,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

- `Reverse: true` — Large files first (go to slower tier)
- `Reverse: false` — Small files first (go to faster tier)

### 3. Sort by Name Pattern

Move specific file types:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "media",
            "Priority": 30,
            "RuleType": "Name",
            "Pattern": ".mp4"
        }
    ]
}
```

### 4. Sort by Time

Move old files to archive:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "documents",
            "Priority": 20,
            "RuleType": "Time",
            "TimeType": "Modify"
        }
    ]
}
```

Time types: `Access`, `Modify`, `Change`

---

## Complete Examples

### Example 1: Home Media Server

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 80, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "videos",
            "Priority": 50,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

**What this does:**
1. Never touch files in `important/` folders
2. Move large videos to HDD
3. Keep small files on SSD

### Example 2: Developer Workstation

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/nvme"},
        {"target": 90, "path": "/mnt/sata"},
        {"target": 100, "path": "/mnt/archive"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "node_modules",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "builds",
            "Priority": 50,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": true
        }
    ]
}
```

**What this does:**
1. 3-tier setup: NVMe → SATA → Archive
2. Never move `node_modules/`
3. Old builds go to archive

### Example 3: Photo/Video Editor

```json
{
    "Tiers": [
        {"target": 80, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "current_project",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "raw",
            "Priority": 60,
            "RuleType": "Name",
            "Pattern": ".dng"
        },
        {
            "PathPrefix": "exports",
            "Priority": 40,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

---

## Systemd Service

### Enable Automatic Runs

```bash
# Copy service files
sudo cp packaging/systemd/*.service /lib/systemd/system/
sudo cp packaging/systemd/*.timer /lib/systemd/system/

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable tires.timer
sudo systemctl start tires.timer

# Check status
sudo systemctl status tires.timer
sudo systemctl list-timers
```

### Customize Schedule

Create `/etc/systemd/system/tires.timer.d/override.conf`:

```ini
[Timer]
# Run every 6 hours instead of hourly
OnCalendar=*-*-* 00/6:00:00

# Or run at specific times
# OnCalendar=*-*-* 02:00:00
# OnCalendar=*-*-* 14:00:00
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart tires.timer
```

---

## Installation Options

### Package Comparison

| Package | System | Command |
|---------|--------|---------|
| `.deb` | Debian, Ubuntu, Mint | `dpkg -i tires_*.deb` |
| `.rpm` | Fedora, RHEL, CentOS | `rpm -ivh tires-*.rpm` |
| `.tar.gz` | Any Linux | Extract and copy binary |

### Manual Installation

```bash
# Download and extract
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64

# Install binary
sudo cp tires /usr/local/bin/
sudo chmod +x /usr/local/bin/tires

# Create config directory
sudo mkdir -p /etc/tires
sudo cp storage.json /etc/tires/storage.json.example

# Verify installation
tires --version 2>/dev/null || echo "Tires installed"
```

---

## Testing

### Run Tests

```bash
# All tests
./Tests/tires-test-runner.sh

# Specific tests
./Tests/tires-test-runner.sh default folders hardlinks

# List available tests
./Tests/tires-test-runner.sh --list
```

### Available Tests

| Test | Description | Requires sudo |
|------|-------------|---------------|
| `default` | Basic file movement | No |
| `folders` | Nested directories | No |
| `hardlinks` | Hardlink preservation | No |
| `symlink` | Symlink preservation | No |
| `folder-rules/*` | Rule priority tests | No |
| `ignore-rule/*` | Folder exclusion tests | No |
| `multi-tier` | 3+ tier distribution | Yes |
| `bigfiles` | Virtual disk tests | Yes |

---

## Troubleshooting

### Common Issues

**Files not moving:**
```bash
# Check logs
journalctl -u tires.service -f

# Verify config
tires /etc/tires/storage.json

# Check tier paths exist
ls -la /mnt/fast /mnt/slow
```

**Permission denied:**
```bash
# Run as root
sudo tires /etc/tires/storage.json

# Or check folder permissions
ls -la /mnt/
```

**Service not starting:**
```bash
# Check service status
sudo systemctl status tires.service
sudo systemctl status tires.timer

# View logs
sudo journalctl -u tires.service -n 50
```

### Log Levels

| Level | When to use |
|-------|-------------|
| `Error` | Production, only errors |
| `Warning` | Production, warnings + errors |
| `Information` | Normal operation (default) |
| `Debug` | Troubleshooting |

---

## FAQ

**Q: Does Tires work without mergerfs?**  
A: Yes! Tires works with any folder structure.

**Q: Will Tires delete my files?**  
A: No, Tires only moves files between tiers.

**Q: Can I run Tires manually?**  
A: Yes, just run `tires /path/to/config.json`.

**Q: How often should Tires run?**  
A: Hourly is default. Adjust based on your needs.

**Q: What happens if a tier fills up?**  
A: Tires respects the `target` percentage and stops when full.

**Q: Does Tires preserve file permissions?**  
A: Yes, all permissions, ownership, and timestamps are preserved.

**Q: Can I exclude specific file types?**  
A: Use `IgnoreRule` with folder paths, or `NameRule` for patterns.

---

## Architecture

```
Tires Components:

┌─────────────────────────────────────────────────────────┐
│  Program.cs (Main Entry Point)                          │
├─────────────────────────────────────────────────────────┤
│  ConfigLoader/     → Load and parse JSON config         │
│  StorageScanner/   → Scan all tiers for files           │
│  StoragePlanner/   → Calculate file distribution        │
│  TierMover/        → Execute file moves                 │
├─────────────────────────────────────────────────────────┤
│  Rules/                                                 │
│    ├── SizeRule    → Sort by file size                  │
│    ├── NameRule    → Sort by filename pattern           │
│    ├── TimeRule    → Sort by access/modify/change time  │
│    └── IgnoreRule  → Exclude folders from moving        │
└─────────────────────────────────────────────────────────┘
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./Tests/tires-test-runner.sh`
5. Submit a pull request

---

## License

ISC License — See [LICENSE](LICENSE) for details.

---

## Links

- [mergerfs](https://github.com/trapexit/mergerfs) — Union filesystem
- [GitHub Issues](https://github.com/gailoks/tires/issues) — Report bugs
- [Discussions](https://github.com/gailoks/tires/discussions) — Ask questions

---

# Русский

## Что такое Tires?

**Tires** — это инструмент для автоматической организации файлов на нескольких устройствах хранения (уровнях) по заданным правилам.

### Зачем мне это нужно?

Представьте, что у вас есть:
- **Быстрый SSD** (дорогой, мало места)
- **Медленный HDD** (дешёвый, много места)

Tires автоматически:
- Перемещает **большие файлы** (видео, архивы) на медленный HDD
- Оставляет **маленькие файлы** (документы, конфиги) на быстром SSD
- **Исключает** важные папки из любого перемещения

**Результат:** Система работает быстро без ручного управления файлами!

### Примеры использования

| Сценарий | Горячий уровень (Быстрый) | Холодный уровень (Медленный) | Преимущество |
|----------|---------------------------|------------------------------|--------------|
| Домашний сервер | SSD 500ГБ | HDD 4ТБ | Быстрая система, медиа на HDD |
| Фоторедактор | NVMe 1ТБ | HDD 8ТБ | Проекты быстро, архивы дёшево |
| Разработчик | SSD 512ГБ | NAS | Код быстро, бэкапы на NAS |
| Медиа-сервер | SSD 100ГБ | HDD 10ТБ | Метаданные быстро, видео на HDD |

---

## Быстрый старт

### 1. Установка

**Из .deb (Debian/Ubuntu):**
```bash
sudo dpkg -i tires_*.deb
sudo apt-get install -f
```

**Из .rpm (Fedora/RHEL):**
```bash
sudo rpm -ivh tires-*.rpm
```

**Из tar.gz (Любой Linux):**
```bash
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64
sudo cp tires /usr/local/bin/
```

### 2. Создание конфигурации

Создайте `/etc/tires/storage.json`:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/fast-ssd"},
        {"target": 100, "path": "/mnt/slow-hdd"}
    ]
}
```

### 3. Запуск

**Вручную:**
```bash
sudo tires /etc/tires/storage.json
```

**Или включить systemd сервис:**
```bash
sudo systemctl enable tires.timer
sudo systemctl start tires.timer
```

Готово! Tires будет автоматически организовывать файлы каждый час.

---

## Как это работает

```
┌─────────────────────────────────────────────────────────────────┐
│                    Рабочий процесс Tires                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. СКАНИРОВАНИЕ  2. АНАЛИЗ          3. ПЕРЕМЕЩЕНИЕ             │
│                                                                 │
│  ┌─────────┐     ┌──────────┐      ┌──────────┐                 │
│  │ /mnt/   │     │ Применить│      │ Перемес- │                 │
│  │ hot/    │────▶│ правила  │─────▶│ тить     │                 │
│  │ /mnt/   │     │ Сортиро- │      │ файлы    │                 │
│  │ cold/   │     │ вать     │      │ между    │                 │
│  └─────────┘     └──────────┘      │ уровнями │                 │
│                                    └──────────┘                 │
│                                                                 │
│  Каждый час (или вручную)                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Пример потока файлов

```
До Tires:                              После Tires:

/mnt/fast-ssd/                         /mnt/fast-ssd/
├── small.txt (5KB)                    ├── small.txt (5KB)      ← осталось
├── config.json (2KB)                  ├── config.json (2KB)    ← осталось
└── video.mp4 (2GB) ← слишком большой! └── doc.pdf (100KB)      ← перемещено

/mnt/slow-hdd/                         /mnt/slow-hdd/
├── doc.pdf (100KB) ← нужно переместить ├── video.mp4 (2GB)     ← перемещено
└── archive.zip (500MB)                └── archive.zip (500MB)
```

---

## Руководство по конфигурации

### Базовая конфигурация

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ]
}
```

### Опции конфигурации

| Опция | Тип | По умолчанию | Описание |
|-------|-----|--------------|----------|
| `IterationLimit` | число | 20 | Максимум перемещений за запуск |
| `LogLevel` | строка | "Information" | Debug, Information, Warning, Error |
| `TemporaryPath` | строка | "tmp" | Имя временной папки при перемещении |
| `Tiers` | массив | требуется | Список уровней хранения |

### Опции уровня (Tier)

| Опция | Тип | Описание |
|-------|-----|----------|
| `target` | число | Процент заполнения (90 = 90% макс) |
| `path` | строка | Абсолютный путь к хранилищу |

---

## Продвинутые возможности

### 1. Исключение папок (IgnoreRule)

Оставить важные файлы на месте:

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
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

Файлы в папках `/mnt/*/important/` **никогда не будут перемещены**.

### 2. Сортировка по размеру

Перемещать большие файлы на медленное хранилище:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "videos",
            "Priority": 50,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

- `Reverse: true` — Большие файлы первыми (на медленный уровень)
- `Reverse: false` — Маленькие файлы первыми (на быстрый уровень)

### 3. Сортировка по паттерну имени

Перемещать определённые типы файлов:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "media",
            "Priority": 30,
            "RuleType": "Name",
            "Pattern": ".mp4"
        }
    ]
}
```

### 4. Сортировка по времени

Перемещать старые файлы в архив:

```json
{
    "FolderRules": [
        {
            "PathPrefix": "documents",
            "Priority": 20,
            "RuleType": "Time",
            "TimeType": "Modify"
        }
    ]
}
```

Типы времени: `Access`, `Modify`, `Change`

---

## Полные примеры

### Пример 1: Домашний медиа-сервер

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 80, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "videos",
            "Priority": 50,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

**Что делает:**
1. Никогда не трогает файлы в папках `important/`
2. Перемещает большие видео на HDD
3. Оставляет маленькие файлы на SSD

### Пример 2: Рабочая станция разработчика

```json
{
    "Tiers": [
        {"target": 90, "path": "/mnt/nvme"},
        {"target": 90, "path": "/mnt/sata"},
        {"target": 100, "path": "/mnt/archive"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "node_modules",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "builds",
            "Priority": 50,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": true
        }
    ]
}
```

**Что делает:**
1. 3 уровня: NVMe → SATA → Архив
2. Никогда не перемещает `node_modules/`
3. Старые сборки уходят в архив

### Пример 3: Фото/Видео редактор

```json
{
    "Tiers": [
        {"target": 80, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "current_project",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "raw",
            "Priority": 60,
            "RuleType": "Name",
            "Pattern": ".dng"
        },
        {
            "PathPrefix": "exports",
            "Priority": 40,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
```

---

## Systemd сервис

### Включить автоматический запуск

```bash
# Скопировать файлы сервиса
sudo cp packaging/systemd/*.service /lib/systemd/system/
sudo cp packaging/systemd/*.timer /lib/systemd/system/

# Перезагрузить и включить
sudo systemctl daemon-reload
sudo systemctl enable tires.timer
sudo systemctl start tires.timer

# Проверить статус
sudo systemctl status tires.timer
sudo systemctl list-timers
```

### Настроить расписание

Создайте `/etc/systemd/system/tires.timer.d/override.conf`:

```ini
[Timer]
# Запуск каждые 6 часов вместо каждого часа
OnCalendar=*-*-* 00/6:00:00

# Или запуск в конкретное время
# OnCalendar=*-*-* 02:00:00
# OnCalendar=*-*-* 14:00:00
```

Затем:
```bash
sudo systemctl daemon-reload
sudo systemctl restart tires.timer
```

---

## Варианты установки

### Сравнение пакетов

| Пакет | Система | Команда |
|-------|---------|---------|
| `.deb` | Debian, Ubuntu, Mint | `dpkg -i tires_*.deb` |
| `.rpm` | Fedora, RHEL, CentOS | `rpm -ivh tires-*.rpm` |
| `.tar.gz` | Любой Linux | Распаковать и скопировать |

### Ручная установка

```bash
# Скачать и распаковать
tar -xzf tires-*-linux-x64.tar.gz
cd tires-*-linux-x64

# Установить бинарник
sudo cp tires /usr/local/bin/
sudo chmod +x /usr/local/bin/tires

# Создать директорию конфигурации
sudo mkdir -p /etc/tires
sudo cp storage.json /etc/tires/storage.json.example

# Проверить установку
tires --version 2>/dev/null || echo "Tires установлен"
```

---

## Тестирование

### Запуск тестов

```bash
# Все тесты
./Tests/tires-test-runner.sh

# Конкретные тесты
./Tests/tires-test-runner.sh default folders hardlinks

# Список доступных тестов
./Tests/tires-test-runner.sh --list
```

### Доступные тесты

| Тест | Описание | Требуется sudo |
|------|----------|----------------|
| `default` | Базовое перемещение файлов | Нет |
| `folders` | Вложенные директории | Нет |
| `hardlinks` | Сохранение жёстких ссылок | Нет |
| `symlink` | Сохранение символьных ссылок | Нет |
| `folder-rules/*` | Тесты приоритетов правил | Нет |
| `ignore-rule/*` | Тесты исключения папок | Нет |
| `multi-tier` | Распределение по 3+ уровням | Да |
| `bigfiles` | Тесты виртуальных дисков | Да |

---

## Устранение неполадок

### Частые проблемы

**Файлы не перемещаются:**
```bash
# Проверить логи
journalctl -u tires.service -f

# Проверить конфиг
tires /etc/tires/storage.json

# Проверить существование путей
ls -la /mnt/fast /mnt/slow
```

**Отказано в доступе:**
```bash
# Запустить от root
sudo tires /etc/tires/storage.json

# Или проверить права папок
ls -la /mnt/
```

**Сервис не запускается:**
```bash
# Проверить статус сервиса
sudo systemctl status tires.service
sudo systemctl status tires.timer

# Просмотреть логи
sudo journalctl -u tires.service -n 50
```

### Уровни логирования

| Уровень | Когда использовать |
|---------|-------------------|
| `Error` | Production, только ошибки |
| `Warning` | Production, предупреждения + ошибки |
| `Information` | Нормальная работа (по умолчанию) |
| `Debug` | Диагностика проблем |

---

## FAQ

**В: Работает ли Tires без mergerfs?**  
О: Да! Tires работает с любой структурой папок.

**В: Будет ли Tires удалять мои файлы?**  
О: Нет, Tires только перемещает файлы между уровнями.

**В: Могу ли я запускать Tires вручную?**  
О: Да, просто выполните `tires /путь/к/конфигу.json`.

**В: Как часто должен запускаться Tires?**  
О: По умолчанию каждый час. Настройте под свои нужды.

**В: Что произойдёт если уровень заполнится?**  
О: Tires уважает процент `target` и останавливается при заполнении.

**В: Сохраняет ли Tires права файлов?**  
О: Да, все права, владельцы и временные метки сохраняются.

**В: Можно ли исключить определённые типы файлов?**  
О: Используйте `IgnoreRule` с путями папок, или `NameRule` для паттернов.

---

## Архитектура

```
Компоненты Tires:

┌─────────────────────────────────────────────────────────┐
│  Program.cs (Точка входа)                               │
├─────────────────────────────────────────────────────────┤
│  ConfigLoader/     → Загрузка и парсинг JSON конфига    │
│  StorageScanner/   → Сканирование всех уровней          │
│  StoragePlanner/   → Расчёт распределения файлов        │
│  TierMover/        → Выполнение перемещений             │
├─────────────────────────────────────────────────────────┤
│  Rules/                                                 │
│    ├── SizeRule    → Сортировка по размеру              │
│    ├── NameRule    → Сортировка по паттерну имени       │
│    ├── TimeRule    → Сортировка по времени              │
│    └── IgnoreRule  → Исключение папок                   │
└─────────────────────────────────────────────────────────┘
```

---

## Вклад

1. Fork репозитория
2. Создайте feature branch
3. Внесите изменения
4. Запустите тесты: `./Tests/tires-test-runner.sh`
5. Отправьте pull request

---

## Лицензия

ISC License — См. [LICENSE](LICENSE) для деталей.

---

## Ссылки

- [mergerfs](https://github.com/trapexit/mergerfs) — Union файловая система
- [GitHub Issues](https://github.com/gailoks/tires/issues) — Сообщить об ошибке
- [Discussions](https://github.com/gailoks/tires/discussions) — Задать вопрос

---
