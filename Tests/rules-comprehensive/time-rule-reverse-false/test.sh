#!/usr/bin/env bash
#===============================================================================
# TimeRule Test with Reverse=false (newer files have higher priority)
# With limited capacity to verify correct sorting
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="time-rule-reverse-false"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=150KB (only 1 file fits)
HOT_CAPACITY=$((150 * 1024))
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
            "PathPrefix": "documents",
            "Priority": 100,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/documents"

# Create files with different modification times
# All same size, so time determines priority
# With Reverse=false, NEWER files have HIGHER priority
create_file "$COLD/documents/oldest.txt" 100
touch -d "7 days ago" "$COLD/documents/oldest.txt"  # Lowest priority

create_file "$COLD/documents/middle.txt" 100
touch -d "3 days ago" "$COLD/documents/middle.txt"

create_file "$COLD/documents/newest.txt" 100
# newest.txt - current time (highest priority)

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh --time-style=long-iso {} \; | sort

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# With Reverse=false: newer files first (higher timestamp = higher priority)
# Hot capacity: 150KB
# newest.txt (100KB, current) should go first
# middle.txt (100KB, 3 days) would exceed capacity

echo "=== Проверка TimeRule с Reverse=false (новые файлы важнее) ==="

if [[ -f "$HOT/documents/newest.txt" ]]; then
    echo "✅ newest.txt (сегодня) на hot - правильный приоритет"
else
    echo "❌ newest.txt (сегодня) должен быть на hot"
    success=false
fi

if [[ -f "$COLD/documents/middle.txt" ]]; then
    echo "✅ middle.txt (3 дня) на cold - не влезает"
else
    echo "❌ middle.txt (3 дня) должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/documents/oldest.txt" ]]; then
    echo "✅ oldest.txt (7 дней) на cold - не влезает"
else
    echo "❌ oldest.txt (7 дней) должен остаться на cold"
    success=false
fi

echo ""
if $success; then
    echo "✅ TimeRule Reverse=false test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ TimeRule Reverse=false test FAILED"
    test_result false "$TEST_NAME"
fi
