#!/usr/bin/env bash
#===============================================================================
# Test: Redistribution of already distributed files
# Verifies that files already on correct tier are not moved unnecessarily
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="dist-redistribution"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
WARM="$TEST_ROOT/warm"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$WARM" "$COLD"

# Mock capacity: Hot=300KB, Warm=600KB, Cold=5MB
HOT_CAPACITY=$((300 * 1024))
WARM_CAPACITY=$((600 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$WARM", "MockCapacity": $WARM_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Pre-distribute files across tiers
# Hot tier - already has small files
create_file "$HOT/small1.bin" 100
create_file "$HOT/small2.bin" 150

# Warm tier - already has medium files
create_file "$WARM/medium1.bin" 200
create_file "$WARM/medium2.bin" 250

# Cold tier - has large files
create_file "$COLD/large1.bin" 400
create_file "$COLD/large2.bin" 500

echo "📊 Initial distribution:"
echo "Hot:" && find "$HOT" -name "*.bin" -exec ls -lh {} \;
echo "Warm:" && find "$WARM" -name "*.bin" -exec ls -lh {} \;
echo "Cold:" && find "$COLD" -name "*.bin" -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

hot_count=$(find "$HOT" -type f -name "*.bin" | wc -l)
warm_count=$(find "$WARM" -type f -name "*.bin" | wc -l)
cold_count=$(find "$COLD" -type f -name "*.bin" | wc -l)

echo "📊 Final distribution: hot=$hot_count, warm=$warm_count, cold=$cold_count"

# Total should be 6
total=$((hot_count + warm_count + cold_count))
if [[ "$total" -ne 6 ]]; then
    echo "❌ Expected 6 files total, found $total"
    success=false
fi

# Small files should be on hot (100+150=250KB < 300KB capacity)
if [[ "$hot_count" -ne 2 ]]; then
    echo "⚠️  Hot tier should have 2 small files, found $hot_count"
fi

# Medium files should be on warm (200+250=450KB < 600KB capacity)
if [[ "$warm_count" -ne 2 ]]; then
    echo "⚠️  Warm tier should have 2 medium files, found $warm_count"
fi

# Large files should stay on cold
if [[ "$cold_count" -ne 2 ]]; then
    echo "⚠️  Cold tier should have 2 large files, found $cold_count"
fi

# Verify specific files are on correct tiers
if [[ -f "$HOT/small1.bin" ]] && [[ -f "$HOT/small2.bin" ]]; then
    echo "✅ Small files correctly on hot"
else
    echo "❌ Small files should be on hot"
    success=false
fi

if [[ -f "$WARM/medium1.bin" ]] && [[ -f "$WARM/medium2.bin" ]]; then
    echo "✅ Medium files correctly on warm"
else
    echo "❌ Medium files should be on warm"
    success=false
fi

if [[ -f "$COLD/large1.bin" ]] && [[ -f "$COLD/large2.bin" ]]; then
    echo "✅ Large files correctly on cold"
else
    echo "❌ Large files should be on cold"
    success=false
fi

if $success; then
    echo "✅ Redistribution test passed"
else
    echo "❌ Redistribution test failed"
fi

test_result "$success" "$TEST_NAME"
