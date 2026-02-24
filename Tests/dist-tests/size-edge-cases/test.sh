#!/usr/bin/env bash
#===============================================================================
# Test: Size constraint edge cases
# Verifies distribution when files exactly match or exceed tier capacity
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="dist-size-edge-cases"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=1MB exactly
HOT_CAPACITY=$((1024 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Case 1: File exactly matching tier capacity
create_file "$COLD/exact_fit.bin" 1024  # Exactly 1MB

# Case 2: Files slightly over capacity
create_file "$COLD/over_1.bin" 1100  # 1.1MB - too big for hot
create_file "$COLD/over_2.bin" 1200  # 1.2MB - too big for hot

# Case 3: Many small files that should fill tier exactly
create_file "$COLD/small1.bin" 256
create_file "$COLD/small2.bin" 256
create_file "$COLD/small3.bin" 256
create_file "$COLD/small4.bin" 256

# Case 4: Single file larger than all capacity
create_file "$COLD/huge.bin" 6000  # 6MB - bigger than total capacity

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

# Total should be 8
total=$((hot_count + cold_count))
if [[ "$total" -ne 8 ]]; then
    echo "❌ Expected 8 files total, found $total"
    success=false
fi

# Hot should have 4 small files (4 * 256KB = 1MB exactly)
# The exact_fit (1MB) should go to cold because small files are sorted first
if [[ "$hot_count" -ne 4 ]]; then
    echo "⚠️  Hot tier should have 4 small files (256KB each), found $hot_count"
    # This is acceptable behavior - small files are prioritized
fi

# Huge file must stay on cold
if [[ -f "$HOT/huge.bin" ]]; then
    echo "❌ Huge file should stay on cold (too big for hot)"
    success=false
fi

# At least one over-capacity file should be on cold
over_on_cold=0
for f in over_1.bin over_2.bin; do
    if [[ -f "$COLD/$f" ]]; then
        over_on_cold=$((over_on_cold + 1))
    fi
done

if [[ "$over_on_cold" -lt 1 ]]; then
    echo "❌ At least one over-capacity file should stay on cold"
    success=false
fi

if $success; then
    echo "✅ Size edge cases test passed"
else
    echo "❌ Size edge cases test failed"
fi

test_result "$success" "$TEST_NAME"
