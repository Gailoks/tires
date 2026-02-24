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

| Test | Description |
|------|-------------|
| `default` | Basic file movement between 2 tiers |
| `folders` | Nested directory handling |
| `hardlinks` | Hardlink preservation during moves |
| `symlink` | Symlink preservation during moves |
| `folder-rules` | Rule priority and sorting tests |
| `ignore-rule` | Folder exclusion tests |
| `bigfiles` | Large file handling (4MB/8MB mock) |
| `capacity-limit` | Capacity limit testing (2MB/10MB mock) |
| `multi-tier` | 3-tier distribution testing |
| `competing-rules` | Competing rules testing |
| `multiple-rules` | Multiple rules for single folder testing |
| `redistribution` | File redistribution testing |
| `rule-priority-capacity` | Rule priority with limited capacity tests |
| `size-edge-cases` | Size edge cases testing |

## Test Structure

```
Tests/
├── tires-test-runner.sh    # Main test runner
├── common.sh               # Shared test utilities
├── default/                # Basic tests
├── folders/                # Nested directory tests
├── hardlinks/              # Hardlink tests
├── symlink/                # Symlink tests
├── folder-rules/           # Rule priority tests
├── ignore-rule/            # Exclusion tests
├── bigfiles/               # Large file tests
├── capacity-limit/         # Capacity limit tests
├── multi-tier/             # 3-tier tests
├── competing-rules/        # Competing rules tests
├── multiple-rules/         # Multiple rules tests
├── redistribution/         # Redistribution tests
├── rule-priority-capacity/ # Rule priority with capacity tests
└── size-edge-cases/        # Size edge cases tests
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
2. Add `config.json` with test configuration
3. Add test files to simulate
4. Run: `./Tests/tires-test-runner.sh my-test`

See existing tests for examples.

## See Also

- **[🇷🇺 Тесты (Русский)](TESTS.ru.md)** — Russian documentation
- **[Examples](../examples/README.md)** — Configuration examples
- **[Documentation](../README.md)** — Main documentation
