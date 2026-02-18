# Tires Examples

Detailed configuration examples for common use cases.

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

**Use case:** Move large videos to slow storage, keep small previews fast

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

- **Reverse: true** — Large files sorted first → go to slower tier
- **Result:** Small videos on SSD, large videos on HDD

### File Distribution

| File | Size | Location |
|------|------|----------|
| preview.mp4 | 5MB | SSD |
| clip.mp4 | 50MB | SSD |
| movie_720p.mp4 | 500MB | HDD |
| movie_4k.mp4 | 4GB | HDD |

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
| NVMe | 80% | Active projects, dependencies |
| SATA | 90% | Recent builds, resources |
| Archive | 100% | Old builds, backups |

### Rules Explained

1. **node_modules (Ignore):** Never move npm packages
2. **current_project (Ignore):** Keep active work fast
3. **builds (Time + Reverse):** Old builds → archive

### Expected Distribution

```
/mnt/nvme/
├── node_modules/     ← Never moves
├── current_project/  ← Never moves
└── recent_builds/    ← New builds only

/mnt/sata/
├── resources/        ← Medium access
└── builds/           ← Recent builds (last week)

/mnt/archive/
├── old_builds/       ← Old builds (reverse time sort)
└── backups/          ← Historical data
```

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

| Pattern | Priority | Movement |
|---------|----------|----------|
| .mp4 | 60 | Videos → slow first |
| .psd | 50 | Photoshop → slow |
| .pdf | 40 | Documents → slow |

### Result

```
/mnt/fast/
├── source/           ← .cpp, .h files
├── configs/          ← .json, .yaml
└── cache/            ← Temporary files

/mnt/slow/
├── media/            ← .mp4 files (priority 60)
├── projects/         ← .psd files (priority 50)
└── documents/        ← .pdf files (priority 40)
```

---

## Example 6: Time-Based Sorting

**Use case:** Move old files to archive, keep recent files fast

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

1. **documents (Modify):** Old documents → slow storage
2. **logs (Access + Reverse):** Recently accessed logs → fast storage

### File Movement by Age

```
documents/:
  today.txt      → /mnt/fast/   (modified today)
  yesterday.txt  → /mnt/fast/   (modified yesterday)
  last_week.txt  → /mnt/slow/   (modified 7 days ago)
  last_month.txt → /mnt/slow/   (modified 30 days ago)

logs/:
  access.log     → /mnt/fast/   (accessed recently)
  old.log        → /mnt/slow/   (not accessed lately)
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

```
/tmp/test-hot/
├── small.bin    (100KB)  ← Fits in 2MB mock
└── medium.bin   (500KB)  ← Fits in remaining space

/tmp/test-cold/
└── large.bin    (1.5MB)  ← Too big for hot tier
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
├── exports/            ← Small exports (priority 50)
└── recent/             ← Recent completed projects

/mnt/archive/ (Slow)
├── exports/            ← Large exports (reverse size)
└── completed/          ← Old projects (reverse time)
```

### Priority Breakdown

| Folder | Rule | Priority | Effect |
|--------|------|----------|--------|
| current_project | Ignore | 100 | Never moves |
| raw | Name (.dng) | 60 | RAW files → archive |
| exports | Size (reverse) | 50 | Large exports → archive |
| completed | Time (reverse) | 30 | Old projects → archive |

---

## See Also

- [Configuration Reference](../README.md#configuration)
- [Rule Types](../README.md#rules)
- [Systemd Service](../README.md#systemd-service)
