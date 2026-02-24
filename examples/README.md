# Tires Examples

Detailed configuration examples for common use cases.

**🇷🇺 [Русская версия](README.ru.md)**

---

## Quick Reference

### Complete Configuration Template

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "LogPath": "/var/log/tires/tires.log",
    "TemporaryPath": "tmp",
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

### Key Features

- **File preservation**: Permissions, ownership, timestamps, and hardlinks are preserved during moves
- **Security hardening**: Systemd service includes NoNewPrivileges, ProtectSystem, ProtectHome
- **No external dependencies**: libMono.Unix.so is bundled in all packages
- **Mock capacity testing**: Test without actual disk limits using `MockCapacity`

---

## How Rules Work

Files are sorted by **score** and assigned to tiers in order:
1. **Lower score** → assigned **first** → goes to **faster tier (SSD/NVMe)**
2. **Higher score** → assigned **later** → goes to **slower tier (HDD/Archive)**

### SizeRule — Quick Reference

| Reverse | Sort Order | First Files Go To | Use Case |
|---------|-----------|-------------------|----------|
| `false` (default) | Small → Large | **Small files on SSD** | Keep small files fast |
| `true` | Large → Small | **Large files on SSD** | Keep large files fast |

### NameRule — Quick Reference

| Reverse | Files Go to SSD | Files Go to HDD | Use Case |
|---------|-----------------|-----------------|----------|
| `false` (default) | **Non-matching** | Matching | Move specific types away |
| `true` | **Matching** | Non-matching | Keep specific types fast |

### TimeRule — Quick Reference

| Reverse | Sort Order | Files Go to SSD | Files Go to HDD | Use Case |
|---------|-----------|-----------------|-----------------|----------|
| `false` (default) | Old → New | **Old files** | New files | Archive recent files |
| `true` | New → Old | **New files** | Old files | Keep recent files fast |

**Remember:** 
- **Size** (default) → **Smaller first** → Small files stay on SSD
- **Size reverse** → **Bigger first** → Large files stay on SSD
- **Name** (default) → **Non-matching first** → Matching files move to HDD
- **Name reverse** → **Matching first** → Matching files stay on SSD
- **Time** (default) → **Old files first** → Old files stay on SSD
- **Time reverse** → **New files first** → New files stay on SSD

---

## Example 1: Basic 2-Tier Setup (SSD + HDD)

**Use case:** Home server with fast SSD and large HDD

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "TemporaryPath": "tmp",
    "Tiers": [
        {
            "target": 90,
            "path": "/mnt/ssd"
        },
        {
            "target": 100,
            "path": "/mnt/hdd"
        }
    ]
}
```

### What This Does

- **SSD (90% full max):** Small files for fast access
- **HDD (100% full max):** Large files, archives, media

### File Movement

| File Type | Size | Moves To |
|-----------|------|----------|
| Documents | < 100KB | SSD |
| Configs | < 50KB | SSD |
| Videos | > 100MB | HDD |
| Archives | > 50MB | HDD |

### Expected Results

```
/mnt/ssd/
├── documents/      (small files)
├── configs/        (small files)
└── photos/         (recent, small)

/mnt/hdd/
├── videos/         (large files)
├── backups/        (large archives)
└── old-photos/     (older, larger)
```

---

## Example 2: Exclude Important Folders

**Use case:** Keep critical files on their current tier

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "backup",
            "Priority": 90,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "critical",
            "Priority": 80,
            "RuleType": "Ignore"
        }
    ]
}
```

### What This Does

1. **Priority 100:** Files in `*/important/*` never move
2. **Priority 90:** Files in `*/backup/*` never move
3. **Priority 80:** Files in `*/critical/*` never move
4. All other files sorted by size (default)

### Directory Structure

```
/mnt/ssd/
├── important/          ← NEVER moves (priority 100)
│   ├── config.json
│   └── keys.db
├── backup/             ← NEVER moves (priority 90)
│   └── latest.tar.gz
└── documents/          ← Can be moved
    └── readme.txt

/mnt/hdd/
├── critical/           ← NEVER moves (priority 80)
│   └── database.sql
└── videos/             ← Can be moved
    └── movie.mp4
```

---

## Example 3: Sort Videos by Size

**Use case:** Keep large videos on fast SSD for quick editing, move small files to HDD

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 90, "path": "/mnt/ssd"},
        {"target": 100, "path": "/mnt/hdd"}
    ],
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

### What This Does

- **`Reverse: true`** — Large files sorted first (lower score) → **go to faster tier (SSD)**
- **Result:** Large videos on SSD, small files on HDD

### File Distribution

| File | Size | Location | Why |
|------|------|----------|-----|
| movie_4k.mp4 | 4GB | **SSD** | Largest, processed first |
| movie_720p.mp4 | 500MB | **SSD** | Large, processed early |
| clip.mp4 | 50MB | HDD | Smaller, processed later |
| preview.mp4 | 5MB | HDD | Smallest, processed last |

### Size Rule Behavior

```
Reverse: true → Score = -Size
- 4GB file: score = -4000000 (lowest) → SSD first
- 5MB file: score = -5000 (highest) → HDD last
```

**Want the opposite?** Use `"Reverse": false` (default):
- Small files (5MB, 50MB) → SSD
- Large files (500MB, 4GB) → HDD

---

## Example 4: 3-Tier Setup (NVMe + SATA + Archive)

**Use case:** High-performance workstation with archive storage

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {
            "target": 80,
            "path": "/mnt/nvme"
        },
        {
            "target": 90,
            "path": "/mnt/sata"
        },
        {
            "target": 100,
            "path": "/mnt/archive"
        }
    ],
    "FolderRules": [
        {
            "PathPrefix": "node_modules",
            "Priority": 100,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "current_project",
            "Priority": 90,
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

### Tier Strategy

| Tier | Target | Purpose |
|------|--------|---------|
| NVMe | 80% | Active projects, dependencies, **new builds** |
| SATA | 90% | Recent builds, resources |
| Archive | 100% | Old builds, backups |

### Rules Explained

1. **node_modules (Ignore):** Never move npm packages
2. **current_project (Ignore):** Keep active work fast
3. **builds (Time + Reverse):** **New builds → NVMe first**, old builds → archive

### Expected Distribution

```
/mnt/nvme/
├── node_modules/     ← Never moves
├── current_project/  ← Never moves
└── recent_builds/    ← New builds (Reverse: true - new files first)

/mnt/sata/
├── resources/        ← Medium access
└── builds/           ← Recent builds (last week)

/mnt/archive/
├── old_builds/       ← Old builds (processed last)
└── backups/          ← Historical data
```

### Time Rule on Builds

With `"RuleType": "Time", "Reverse": true`:
- **New builds** (modified today) → low negative score → **NVMe first**
- **Old builds** (modified months ago) → high negative score → **archive last**

---

## Example 5: Sort by File Pattern

**Use case:** Move specific file types to appropriate tiers

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "media",
            "Priority": 60,
            "RuleType": "Name",
            "Pattern": ".mp4"
        },
        {
            "PathPrefix": "projects",
            "Priority": 50,
            "RuleType": "Name",
            "Pattern": ".psd"
        },
        {
            "PathPrefix": "documents",
            "Priority": 40,
            "RuleType": "Name",
            "Pattern": ".pdf"
        }
    ]
}
```

### What This Does

**Default behavior (Reverse: false):** Non-matching files get score 0, matching files get score 1

| Pattern | Priority | Non-Match Score | Match Score | Files Go to Fast | Files Go to Slow |
|---------|----------|-----------------|-------------|------------------|------------------|
| .mp4 | 60 | 0 | 1 | **Other files** | .mp4 files |
| .psd | 50 | 0 | 1 | **Other files** | .psd files |
| .pdf | 40 | 0 | 1 | **Other files** | .pdf files |

### Result

```
/mnt/fast/
├── source/           ← .cpp, .h files (don't match any pattern)
├── configs/          ← .json, .yaml (don't match any pattern)
└── cache/            ← Temporary files (don't match any pattern)

/mnt/slow/
├── media/            ← .mp4 files (match priority 60)
├── projects/         ← .psd files (match priority 50)
└── documents/        ← .pdf files (match priority 40)
```

### Name Rule Behavior

```
Reverse: false → Matching files get score 1, non-matching get 0
- .cpp file: score = 0 (lowest) → fast tier first
- .mp4 file: score = 1 (highest) → slow tier last
```

**Want to keep matching files fast?** Use `"Reverse": true`:
- Matching files (score -1) → fast tier
- Non-matching files (score 0) → slow tier

---

## Example 6: Time-Based Sorting

**Use case:** Keep old files fast, move recent files to archive (or vice versa)

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 90, "path": "/mnt/fast"},
        {"target": 100, "path": "/mnt/slow"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "documents",
            "Priority": 50,
            "RuleType": "Time",
            "TimeType": "Modify"
        },
        {
            "PathPrefix": "logs",
            "Priority": 40,
            "RuleType": "Time",
            "TimeType": "Access",
            "Reverse": true
        }
    ]
}
```

### TimeType Options

| Value | Description |
|-------|-------------|
| `Modify` | Last modification time |
| `Access` | Last access time |
| `Change` | Last metadata change |

### What This Does

**Timestamp scoring:** Older files = lower timestamp = lower score → processed first

1. **documents (Modify, default):** Old files have low timestamp → **old files → fast**, new files → slow
2. **logs (Access + Reverse):** New files get negative score → **recently accessed → fast**, old → slow

### File Movement by Age

```
documents/ (Reverse: false - old files first):
  old_doc.txt      → /mnt/fast/   (modified 30 days ago, lowest timestamp)
  last_week.txt    → /mnt/fast/   (modified 7 days ago)
  yesterday.txt    → /mnt/slow/   (modified 1 day ago)
  today.txt        → /mnt/slow/   (modified today, highest timestamp)

logs/ (Reverse: true - new files first):
  access.log       → /mnt/fast/   (accessed today, lowest negative score)
  recent.log       → /mnt/fast/   (accessed yesterday)
  old.log          → /mnt/slow/   (not accessed lately, highest negative score)
```

### Time Rule Behavior

```
Reverse: false → Score = timestamp (seconds since epoch)
- Old file (year 2020): score = 1577836800 (lower) → fast tier first
- New file (year 2025): score = 1735689600 (higher) → slow tier last

Reverse: true → Score = -timestamp
- New file (year 2025): score = -1735689600 (lower) → fast tier first
- Old file (year 2020): score = -1577836800 (higher) → slow tier last
```

---

## Example 7: Testing with MockCapacity

**Use case:** Test tiered storage without actual disk limits

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Debug",
    "TemporaryPath": "tmp",
    "Tiers": [
        {
            "target": 100,
            "path": "/tmp/test-hot",
            "MockCapacity": 2097152
        },
        {
            "target": 100,
            "path": "/tmp/test-cold",
            "MockCapacity": 10485760
        }
    ]
}
```

### MockCapacity Values

| Tier | MockCapacity | Real Equivalent |
|------|--------------|-----------------|
| Hot | 2097152 (2MB) | 2MB partition |
| Cold | 10485760 (10MB) | 10MB partition |

### Test Files

```bash
# Create test files
dd if=/dev/zero of=/tmp/test-cold/small.bin bs=1K count=100
dd if=/dev/zero of=/tmp/test-cold/medium.bin bs=1K count=500
dd if=/dev/zero of=/tmp/test-cold/large.bin bs=1K count=1500

# Run tires
tires /tmp/test-config.json

# Check distribution
find /tmp/test-hot -name "*.bin"   # Should have small files
find /tmp/test-cold -name "*.bin"  # Should have large files
```

### Expected Result

**Default behavior (no FolderRules):** Small files sorted first → go to hot tier

```
/tmp/test-hot/
├── small.bin    (100KB)  ← Smallest, processed first → hot tier
└── medium.bin   (500KB)  ← Medium, fits in remaining space

/tmp/test-cold/
└── large.bin    (1.5MB)  ← Largest, processed last → cold tier
```

---

## Example 8: Photo/Video Editor Workflow

**Use case:** Keep current projects fast, archive old work

### Configuration

```json
{
    "IterationLimit": 20,
    "LogLevel": "Information",
    "Tiers": [
        {"target": 80, "path": "/mnt/nvme"},
        {"target": 90, "path": "/mnt/sata"},
        {"target": 100, "path": "/mnt/archive"}
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
            "Priority": 50,
            "RuleType": "Size",
            "Reverse": true
        },
        {
            "PathPrefix": "completed",
            "Priority": 30,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": true
        }
    ]
}
```

### Workflow

```
/mnt/nvme/ (Fastest)
├── current_project/    ← Never moves (priority 100)
│   ├── active.psd
│   └── working.raw
└── cache/              ← Recent cache files

/mnt/sata/ (Fast)
├── raw/                ← .dng files (priority 60)
├── exports/            ← Large exports (priority 50, Reverse: true)
└── recent/             ← Recent completed projects

/mnt/archive/ (Slow)
├── exports/            ← Small exports (processed last)
└── completed/          ← Old projects (reverse time)
```

### Priority Breakdown

| Folder | Rule | Priority | Effect |
|--------|------|----------|--------|
| current_project | Ignore | 100 | Never moves |
| raw | Name (.dng) | 60 | RAW files → NVMe first |
| exports | Size (reverse) | 50 | **Large exports → NVMe**, small → archive |
| completed | Time (reverse) | 30 | **New projects → NVMe**, old → archive |

### Size Rule on Exports

With `"RuleType": "Size", "Reverse": true`:
- **Large exports** (4K videos, 500MB+) → sorted first → **stay on NVMe**
- **Small exports** (previews, 10MB) → sorted last → move to archive

**Why?** Large files get negative score (e.g., -500000000), small files get less negative score (e.g., -10000000). Lower scores go to faster tiers.

---

## See Also

- [Configuration Reference](../README.md#configuration)
- [Rule Types](../README.md#rules)
- [Systemd Service](../README.md#systemd-service)
