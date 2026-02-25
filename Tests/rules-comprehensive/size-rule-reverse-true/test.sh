#!/usr/bin/env bash
#===============================================================================
# SizeRule Test with Reverse=true (smaller files have higher priority)
# With limited capacity to verify correct sorting
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="size-rule-reverse-true"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=200KB (limited - only small files fit)
HOT_CAPACITY=$((200 * 1024))
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
        {
            "PathPrefix": "files",
            "Priority": 100,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/files"

# Create files of different sizes
# With Reverse=true, smaller files have HIGHER priority
create_file "$COLD/files/tiny.bin" 50      # Should go to hot (highest priority)
create_file "$COLD/files/small.bin" 80     # Should go to hot
create_file "$COLD/files/medium.bin" 150   # Should stay on cold (would exceed 200KB)
create_file "$COLD/files/large.bin" 300    # Should stay on cold

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# With Reverse=true: smaller files first
# Hot capacity: 200KB
# tiny.bin (50KB) + small.bin (80KB) = 130KB fits
# medium.bin (150KB) would make it 280KB - doesn't fit

echo "=== Проверка SizeRule с Reverse=true (меньшие файлы важнее) ==="

if [[ -f "$HOT/files/tiny.bin" ]]; then
    echo "✅ tiny.bin (50KB) на hot - правильный приоритет"
else
    echo "❌ tiny.bin (50KB) должен быть на hot"
    success=false
fi

if [[ -f "$HOT/files/small.bin" ]]; then
    echo "✅ small.bin (80KB) на hot - правильный приоритет"
else
    echo "❌ small.bin (80KB) должен быть на hot"
    success=false
fi

if [[ -f "$COLD/files/medium.bin" ]]; then
    echo "✅ medium.bin (150KB) на cold - не влезает"
else
    echo "❌ medium.bin (150KB) должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/files/large.bin" ]]; then
    echo "✅ large.bin (300KB) на cold - не влезает"
else
    echo "❌ large.bin (300KB) должен остаться на cold"
    success=false
fi

# Verify hot tier size
hot_size=$(find "$HOT" -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
expected_hot_size=$((50 * 1024 + 80 * 1024))
if [[ "$hot_size" -eq "$expected_hot_size" ]]; then
    echo "✅ Размер hot tier: $((hot_size / 1024))KB (ожидалось 130KB)"
else
    echo "⚠️  Размер hot tier: $((hot_size / 1024))KB (ожидалось 130KB)"
fi

echo ""
if $success; then
    echo "✅ SizeRule Reverse=true test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ SizeRule Reverse=true test FAILED"
    test_result false "$TEST_NAME"
fi
