# Tires — Full Documentation

## Configuration

### Core Options

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "LogPath": "/var/log/tires/tires.log",
    "TemporaryPath": "tmp",
    "RunInterval": "hourly",
    "ProcessPriority": 2,
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
| `LogPath` | string | "/var/log/tires/tires.log" | Path to log file |
| `TemporaryPath` | string | "tmp" | Temp folder during moves |
| `RunInterval` | string | "hourly" | How often to run (minutely, hourly, daily, weekly, monthly, or systemd calendar format) |
| `ProcessPriority` | int | 2 | Process priority: -20 (highest) to 19 (lowest). Default 2 = Idle |
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

| Reverse | Sort Order | Files Go to SSD | Files Go to HDD |
|---------|-----------|-----------------|-----------------|
| `false` (default) | Small → Large | **Small files** | Large files |
| `true` | Large → Small | **Large files** | Small files |

**Examples:**

- `"Reverse": false` — Small files → **SSD**, large files → HDD
- `"Reverse": true` — Large files → **SSD**, small files → HDD

### NameRule — Sort by Pattern

```json
{"PathPrefix": "media", "Priority": 30, "RuleType": "Name", "Pattern": ".mp4"}
```

| Reverse | Match Score | Non-Match Score | Files Go to SSD | Files Go to HDD |
|---------|-------------|-----------------|-----------------|-----------------|
| `false` (default) | 1 | 0 | **Matching** | Non-matching |
| `true` | -1 | 0 | **Non-matching** | Matching |

**Examples:**

- `"Reverse": false` — Matching files (e.g., .mp4) → **SSD**, non-matching → HDD
- `"Reverse": true` — Non-matching files → **SSD**, matching files → HDD

### TimeRule — Sort by Time

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

---

## Systemd Service

### Enable Automatic Runs

**Packages (.deb/.rpm):** Files are installed automatically.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tires.timer
```

**Manual installation (tar.gz):**

```bash
sudo cp packaging/systemd/tires.service /lib/systemd/system/
sudo cp packaging/systemd/tires.timer /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tires.timer
```

### Configure Run Interval

Edit `/etc/tires/storage.json`:

```json
{"RunInterval": "daily"}
```

Supported values:
- `minutely`, `hourly` (default), `daily`, `weekly`, `monthly`
- Custom systemd calendar format (e.g., `*-*-* 02:00:00` for daily at 2 AM)

Apply configuration:

```bash
sudo /usr/bin/tires-setup-timer.sh
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

### Security Hardening

The systemd service includes security hardening:

- `NoNewPrivileges=true` — Prevent privilege escalation
- `ProtectSystem=strict` — Read-only system directories
- `ProtectHome=read-only` — Read-only home directories
- `PrivateTmp=true` — Isolated temporary directory

---

## Troubleshooting

### Files Not Moving

```bash
# Check logs
journalctl -u tires.service -f

# Verify config
sudo tires /etc/tires/storage.json

# Check paths
ls -la /mnt/ssd /mnt/hdd
```

### Permission Denied

```bash
sudo tires /etc/tires/storage.json
ls -la /etc/tires/storage.json
```

### Service Issues

```bash
sudo systemctl status tires.service tires.timer
sudo journalctl -u tires.service -n 50
sudo systemctl restart tires.timer
```

### Timer Not Running

```bash
systemctl list-timers | grep tires
sudo systemctl enable --now tires.timer
```

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
├─────────────────────────────────────────┤
│  Systemd Service (Security Hardened)    │
│  - NoNewPrivileges, ProtectSystem       │
│  - ProtectHome, PrivateTmp              │
└─────────────────────────────────────────┘
```

### Key Components

| Component | Description |
|-----------|-------------|
| **ConfigLoader** | Loads and parses storage.json configuration |
| **StorageScanner** | Scans tier directories and collects file information |
| **StoragePlanner** | Calculates file distribution based on rules and priorities |
| **TierMover** | Executes file moves while preserving metadata (permissions, timestamps, hardlinks) |
| **Rules** | SizeRule, NameRule, TimeRule, IgnoreRule for smart sorting |

---

## See Also

- **[Examples](../examples/README.md)** — Configuration examples
- **[Tests](TESTS.md)** — Test suite documentation
- **[Русская документация](README.ru.md)** — Russian documentation
