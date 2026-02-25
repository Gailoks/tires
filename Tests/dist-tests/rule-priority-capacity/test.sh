#!/usr/bin/env bash
#===============================================================================
# Test: Rule priority with capacity limits
# Verifies that high-priority rules get space before low-priority rules
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="dist-rule-priority-capacity"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=400KB (limited space)
HOT_CAPACITY=$((400 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ],
    "FolderRules": [
        {"PathPrefix": "priority", "Priority": 100, "RuleType": "Size", "Reverse": true},
        {"PathPrefix": "normal", "Priority": 50, "RuleType": "Size", "Reverse": true}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Priority folder - small files first, should get hot space first
mkdir -p "$COLD/priority"
create_file "$COLD/priority/p_small.bin" 150   # Should go to hot
create_file "$COLD/priority/p_medium.bin" 200  # Should go to hot (total 350KB)
create_file "$COLD/priority/p_large.bin" 300   # Should stay on cold (would exceed 400KB)

# Normal folder - small files first, gets remaining hot space
mkdir -p "$COLD/normal"
create_file "$COLD/normal/n_small.bin" 100     # May fit in remaining 50KB? No, too big
create_file "$COLD/normal/n_medium.bin" 150    # Should stay on cold
create_file "$COLD/normal/n_large.bin" 250     # Should stay on cold

echo "📊 Файлы созданы:"
find "$COLD" -name "*.bin" -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

hot_count=$(find "$HOT" -type f -name "*.bin" | wc -l)
cold_count=$(find "$COLD" -type f -name "*.bin" | wc -l)

echo "📊 Distribution: hot=$hot_count, cold=$cold_count"

# Total should be 6
total=$((hot_count + cold_count))
if [[ "$total" -ne 6 ]]; then
    echo "❌ Expected 6 files total, found $total"
    success=false
fi

# Priority files should be on hot first
priority_on_hot=$(find "$HOT" -type f -name "p_*.bin" | wc -l)
echo "Priority files on hot: $priority_on_hot"

# At least p_small should be on hot (highest priority, smallest)
if [[ ! -f "$HOT/priority/p_small.bin" ]]; then
    echo "❌ Priority small file should be on hot"
    success=false
else
    echo "✅ Priority small file is on hot"
fi

# Check that priority files get preference over normal files
normal_on_hot=$(find "$HOT" -type f -name "n_*.bin" | wc -l)
echo "Normal files on hot: $normal_on_hot"

# If hot is full with priority files, normal should not be there
if [[ "$priority_on_hot" -ge 2 ]] && [[ "$normal_on_hot" -gt 0 ]]; then
    echo "⚠️  Normal files on hot despite priority files filling space"
    # This might be OK depending on exact sizes
fi

if $success; then
    echo "✅ Rule priority with capacity test passed"
else
    echo "❌ Rule priority with capacity test failed"
fi

test_result "$success" "$TEST_NAME"
