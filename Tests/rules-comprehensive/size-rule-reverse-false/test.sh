#!/usr/bin/env bash
#===============================================================================
# SizeRule Test with Reverse=false (larger files have higher priority)
# With limited capacity to verify correct sorting
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="size-rule-reverse-false"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=400KB (limited - only large files fit first)
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
        {
            "PathPrefix": "files",
            "Priority": 100,
            "RuleType": "Size",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/files"

# Create files of different sizes
# With Reverse=false, larger files have HIGHER priority
create_file "$COLD/files/tiny.bin" 50      # Should go to hot (fills remaining space)
create_file "$COLD/files/small.bin" 80     # Should stay on cold (would exceed 400KB)
create_file "$COLD/files/medium.bin" 150   # Should go to hot
create_file "$COLD/files/large.bin" 200    # Should go to hot (highest priority)

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# With Reverse=false: larger files first
# Hot capacity: 400KB
# large.bin (200KB) + medium.bin (150KB) + tiny.bin (50KB) = 400KB fits exactly
# small.bin (80KB) would make it 480KB - doesn't fit

echo "=== Проверка SizeRule с Reverse=false (большие файлы важнее) ==="

if [[ -f "$HOT/files/large.bin" ]]; then
    echo "✅ large.bin (200KB) на hot - правильный приоритет"
else
    echo "❌ large.bin (200KB) должен быть на hot"
    success=false
fi

if [[ -f "$HOT/files/medium.bin" ]]; then
    echo "✅ medium.bin (150KB) на hot - правильный приоритет"
else
    echo "❌ medium.bin (150KB) должен быть на hot"
    success=false
fi

if [[ -f "$HOT/files/tiny.bin" ]]; then
    echo "✅ tiny.bin (50KB) на hot - заполняет остаток"
else
    echo "❌ tiny.bin (50KB) должен быть на hot (заполняет остаток)"
    success=false
fi

if [[ -f "$COLD/files/small.bin" ]]; then
    echo "✅ small.bin (80KB) на cold - не влезает"
else
    echo "❌ small.bin (80KB) должен остаться на cold"
    success=false
fi

# Verify hot tier size
hot_size=$(find "$HOT" -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
expected_hot_size=$((200 * 1024 + 150 * 1024 + 50 * 1024))
if [[ "$hot_size" -eq "$expected_hot_size" ]]; then
    echo "✅ Размер hot tier: $((hot_size / 1024))KB (ожидалось 400KB)"
else
    echo "⚠️  Размер hot tier: $((hot_size / 1024))KB (ожидалось 400KB)"
fi

echo ""
if $success; then
    echo "✅ SizeRule Reverse=false test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ SizeRule Reverse=false test FAILED"
    test_result false "$TEST_NAME"
fi
