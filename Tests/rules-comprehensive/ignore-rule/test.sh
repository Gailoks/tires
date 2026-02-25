#!/usr/bin/env bash
#===============================================================================
# IgnoreRule Test - verifies excluded folders are not moved
# With other rules to ensure ignored files stay put
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="ignore-rule-comprehensive"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
WARM="$TEST_ROOT/warm"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$WARM" "$COLD"

# Mock capacity: Hot=200KB, Warm=400KB, Cold=5MB
HOT_CAPACITY=$((200 * 1024))
WARM_CAPACITY=$((400 * 1024))
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
    ],
    "FolderRules": [
        {
            "PathPrefix": "models",
            "Priority": 1000,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "cloud",
            "Priority": 1000,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "cache",
            "Priority": 100,
            "RuleType": "Size",
            "Reverse": true
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Ignored folders - should NEVER be moved
mkdir -p "$COLD/models"
mkdir -p "$COLD/cloud"
create_file "$COLD/models/large_model.bin" 500   # Large but ignored
create_file "$COLD/models/small_model.bin" 50    # Small but ignored
create_file "$COLD/cloud/sync_file.dat" 300      # Ignored

# Movable files
mkdir -p "$COLD/cache"
create_file "$COLD/cache/small_cache.dat" 100    # Should go to hot
create_file "$COLD/cache/large_cache.dat" 200    # Should go to warm (hot full)

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

echo "=== Проверка IgnoreRule ==="

# Ignored files should stay on cold regardless of size
if [[ -f "$COLD/models/large_model.bin" ]]; then
    echo "✅ models/large_model.bin (500KB) на cold - игнорируется"
else
    echo "❌ models/large_model.bin должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/models/small_model.bin" ]]; then
    echo "✅ models/small_model.bin (50KB) на cold - игнорируется"
else
    echo "❌ models/small_model.bin должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/cloud/sync_file.dat" ]]; then
    echo "✅ cloud/sync_file.dat (300KB) на cold - игнорируется"
else
    echo "❌ cloud/sync_file.dat должен остаться на cold"
    success=false
fi

# Check no ignored files on hot or warm
ignored_on_hot=$(find "$HOT" -type f \( -path "*/models/*" -o -path "*/cloud/*" \) 2>/dev/null | wc -l)
ignored_on_warm=$(find "$WARM" -type f \( -path "*/models/*" -o -path "*/cloud/*" \) 2>/dev/null | wc -l)

if [[ "$ignored_on_hot" -eq 0 ]]; then
    echo "✅ Нет игнорируемых файлов на hot"
else
    echo "❌ Найдены игнорируемые файлы на hot: $ignored_on_hot"
    success=false
fi

if [[ "$ignored_on_warm" -eq 0 ]]; then
    echo "✅ Нет игнорируемых файлов на warm"
else
    echo "❌ Найдены игнорируемые файлы на warm: $ignored_on_warm"
    success=false
fi

echo ""
echo "=== Проверка Cache (movable files) ==="

if [[ -f "$HOT/cache/small_cache.dat" ]]; then
    echo "✅ cache/small_cache.dat (100KB) на hot"
else
    echo "❌ cache/small_cache.dat должен быть на hot"
    success=false
fi

if [[ -f "$WARM/cache/large_cache.dat" ]]; then
    echo "✅ cache/large_cache.dat (200KB) на warm"
else
    echo "❌ cache/large_cache.dat должен быть на warm"
    success=false
fi

echo ""
echo "=== Итоговое распределение ==="
echo "Hot: $(find "$HOT" -type f | wc -l) файлов"
echo "Warm: $(find "$WARM" -type f | wc -l) файлов"
echo "Cold: $(find "$COLD" -type f | wc -l) файлов (включая ignored)"

echo ""
if $success; then
    echo "✅ IgnoreRule comprehensive test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ IgnoreRule comprehensive test FAILED"
    test_result false "$TEST_NAME"
fi
