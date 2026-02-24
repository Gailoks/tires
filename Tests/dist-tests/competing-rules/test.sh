#!/usr/bin/env bash
#===============================================================================
# Test: Mixed rules with competing space requirements
# Verifies distribution when multiple rules compete for limited tier space
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="dist-competing-rules"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=500KB (very limited)
HOT_CAPACITY=$((500 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Debug",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ],
    "FolderRules": [
        {"PathPrefix": "urgent", "Priority": 100, "RuleType": "Size", "Reverse": false},
        {"PathPrefix": "normal", "Priority": 50, "RuleType": "Size", "Reverse": false}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Urgent folder - highest priority, small files first
mkdir -p "$COLD/urgent"
create_file "$COLD/urgent/u1.bin" 100   # Priority 1, should go to hot
create_file "$COLD/urgent/u2.bin" 150   # Priority 2, should go to hot
create_file "$COLD/urgent/u3.bin" 200   # Priority 3, may fit in hot (total 450KB)
create_file "$COLD/urgent/u4.bin" 100   # Priority 4, won't fit (would be 550KB)

# Normal folder - lower priority, small files first
mkdir -p "$COLD/normal"
create_file "$COLD/normal/n1.bin" 50    # Should get remaining hot space (50KB)
create_file "$COLD/normal/n2.bin" 100   # Won't fit on hot
create_file "$COLD/normal/n3.bin" 150   # Won't fit on hot

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

# Total should be 7
total=$((hot_count + cold_count))
if [[ "$total" -ne 7 ]]; then
    echo "❌ Expected 7 files total, found $total"
    success=false
fi

# Check urgent files on hot
urgent_on_hot=$(find "$HOT" -type f -name "u*.bin" | wc -l)
echo "Urgent files on hot: $urgent_on_hot"

# Check normal files on hot
normal_on_hot=$(find "$HOT" -type f -name "n*.bin" | wc -l)
echo "Normal files on hot: $normal_on_hot"

# Urgent files should have priority
# Expected: u1(100) + u2(150) + u3(200) = 450KB on hot
# OR: u1(100) + u2(150) + n1(50) = 300KB if n1 sneaks in

# At minimum, u1 and u2 should be on hot (250KB)
if [[ ! -f "$HOT/urgent/u1.bin" ]]; then
    echo "❌ Urgent u1 should be on hot (highest priority)"
    success=false
fi

if [[ ! -f "$HOT/urgent/u2.bin" ]]; then
    echo "❌ Urgent u2 should be on hot (highest priority)"
    success=false
fi

# n1 (50KB) might fit if there's space after urgent files
# This tests if the sorting respects priority order

echo "Files on hot tier:"
find "$HOT" -name "*.bin" -exec ls -l {} \;

if $success; then
    echo "✅ Competing rules test passed"
else
    echo "❌ Competing rules test failed"
fi

test_result "$success" "$TEST_NAME"
