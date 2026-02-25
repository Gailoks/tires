# Tires — Test Suite

All tests run **without sudo** using `MockCapacity` to simulate tier sizes.

## Run Tests

```bash
# All tests
./Tests/tires-test-runner.sh

# List available tests
./Tests/tires-test-runner.sh --list

# Specific tests
./Tests/tires-test-runner.sh default folders hardlinks
```

## Available Tests

### Rule Tests (with Size Constraints)

| Test | Description |
|------|-------------|
| `rules-comprehensive/size-rule-reverse-true` | SizeRule: smaller files first, limited capacity |
| `rules-comprehensive/size-rule-reverse-false` | SizeRule: larger files first, limited capacity |
| `rules-comprehensive/time-rule-reverse-true` | TimeRule: older files first, limited capacity |
| `rules-comprehensive/time-rule-reverse-false` | TimeRule: newer files first, limited capacity |
| `rules-comprehensive/name-rule` | NameRule: pattern matching, limited capacity |
| `rules-comprehensive/ignore-rule` | IgnoreRule: excluded folders stay in place |

### Core Functionality Tests

| Test | Description |
|------|-------------|
| `default` | Basic file movement between 2 tiers |
| `folders` | Nested directory handling |
| `hardlinks` | Hardlink preservation during moves |
| `symlink` | Symlink preservation during moves |
| `logging` | Log file format and rotation |

### Distribution Tests

| Test | Description |
|------|-------------|
| `dist-tests/competing-rules` | Competing rules with different priorities |
| `dist-tests/multiple-rules` | Multiple rules for single folder |
| `dist-tests/redistribution` | File redistribution (preserving correct placement) |
| `dist-tests/rule-priority-capacity` | Rule priority with limited capacity |
| `dist-tests/size-edge-cases` | Size edge cases testing |

### Integration Tests

| Test | Description |
|------|-------------|
| `bigfiles` | Large file handling (4MB/8MB mock) |
| `capacity-limit` | Capacity limit testing (2MB/10MB mock) |
| `multi-tier` | 3-tier distribution testing |
| `folder-rules/priority` | Rule priority tests |
| `folder-rules/time-rule` | TimeRule basic test |
| `folder-rules/name-rule` | NameRule basic test |
| `ignore-rule/pattern` | IgnoreRule pattern test |
| `ignore-rule/size` | IgnoreRule size-based test |

## Test Structure

```
Tests/
├── tires-test-runner.sh        # Main test runner
├── common.sh                   # Shared test utilities
├── rules-comprehensive/        # Rule tests with size constraints
│   ├── size-rule-reverse-true/ # SizeRule: smaller files first
│   ├── size-rule-reverse-false/# SizeRule: larger files first
│   ├── time-rule-reverse-true/ # TimeRule: older files first
│   ├── time-rule-reverse-false/# TimeRule: newer files first
│   ├── name-rule/              # NameRule: pattern matching
│   └── ignore-rule/            # IgnoreRule: excluded folders
├── default/                    # Basic tests
├── folders/                    # Nested directory tests
├── hardlinks/                  # Hardlink tests
├── symlink/                    # Symlink tests
├── logging/                    # Logging tests
├── folder-rules/               # Rule priority tests
│   ├── priority/
│   ├── time-rule/
│   └── name-rule/
├── ignore-rule/                # Exclusion tests
│   ├── pattern/
│   └── size/
├── dist-tests/                 # Distribution tests
│   ├── competing-rules/
│   ├── multiple-rules/
│   ├── redistribution/
│   ├── rule-priority-capacity/
│   └── size-edge-cases/
├── bigfiles/                   # Large file tests
├── capacity-limit/             # Capacity limit tests
└── multi-tier/                 # 3-tier tests
```

## How Tests Work

Tests use `MockCapacity` in configuration to simulate tier sizes without requiring actual disk partitions:

```json
{
    "Tiers": [
        {"target": 100, "path": "/tmp/hot", "MockCapacity": 2097152},
        {"target": 100, "path": "/tmp/cold", "MockCapacity": 10485760}
    ]
}
```

This allows tests to run:
- ✅ Without root privileges
- ✅ Without actual disk partitions
- ✅ In CI/CD environments
- ✅ With predictable results

## Testing Features

### Metadata Preservation

Tests verify that file metadata is preserved during moves:
- File permissions
- Ownership (user/group)
- Timestamps (access, modify, change)
- Hardlinks
- Symlinks

### MockCapacity

`MockCapacity` values are specified in bytes:
- `2097152` = 2 MB
- `10485760` = 10 MB
- `1073741824` = 1 GB

### Running Without Sudo

All tests use temporary directories in `/tmp` and do not require superuser privileges.

## Adding New Tests

1. Create a test directory: `mkdir Tests/my-test`
2. Add `test.sh` with test script
3. Run: `./Tests/tires-test-runner.sh my-test`

See existing tests for examples.

## Test Count

As of **February 2026**:
- **24 total tests**
- **6 comprehensive rule tests** with size constraints
- **18 core functionality tests**

All tests pass ✅

## See Also

- **[🇷🇺 Тесты (Русский)](TESTS.ru.md)** — Russian documentation
- **[Examples](../examples/README.md)** — Configuration examples
- **[Documentation](../README.md)** — Main documentation
