#!/usr/bin/env bash
#===============================================================================
# NameRule Test with pattern matching
# With limited capacity to verify correct sorting
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="name-rule"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=250KB (only matching files fit)
HOT_CAPACITY=$((250 * 1024))
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
            "PathPrefix": "media",
            "Priority": 100,
            "RuleType": "Name",
            "Pattern": ".mp4",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/media"

# Create files with different extensions
# .mp4 files should have higher priority (matching pattern)
create_file "$COLD/media/video1.mp4" 100   # Matching - high priority
create_file "$COLD/media/video2.mp4" 150   # Matching - high priority
create_file "$COLD/media/document.pdf" 50  # Non-matching - low priority
create_file "$COLD/media/archive.zip" 80   # Non-matching - low priority

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# NameRule with Pattern=".mp4" and Reverse=false
# .mp4 files get score based on having matching extension (higher priority)
# Hot capacity: 250KB
# video1.mp4 (100KB) + video2.mp4 (150KB) = 250KB fits exactly

echo "=== Проверка NameRule с Pattern=.mp4 ==="

if [[ -f "$HOT/media/video1.mp4" ]]; then
    echo "✅ video1.mp4 (matching) на hot"
else
    echo "❌ video1.mp4 (matching) должен быть на hot"
    success=false
fi

if [[ -f "$HOT/media/video2.mp4" ]]; then
    echo "✅ video2.mp4 (matching) на hot"
else
    echo "❌ video2.mp4 (matching) должен быть на hot"
    success=false
fi

if [[ -f "$COLD/media/document.pdf" ]]; then
    echo "✅ document.pdf (non-matching) на cold"
else
    echo "❌ document.pdf (non-matching) должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/media/archive.zip" ]]; then
    echo "✅ archive.zip (non-matching) на cold"
else
    echo "❌ archive.zip (non-matching) должен остаться на cold"
    success=false
fi

# Verify no non-mp4 files on hot
non_mp4_on_hot=$(find "$HOT" -type f ! -name "*.mp4" 2>/dev/null | wc -l)
if [[ "$non_mp4_on_hot" -eq 0 ]]; then
    echo "✅ На hot только .mp4 файлы"
else
    echo "❌ На hot найдены не-.mp4 файлы: $non_mp4_on_hot"
    success=false
fi

echo ""
if $success; then
    echo "✅ NameRule test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ NameRule test FAILED"
    test_result false "$TEST_NAME"
fi
