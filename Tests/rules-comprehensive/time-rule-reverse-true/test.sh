#!/usr/bin/env bash
#===============================================================================
# TimeRule Test with Reverse=true (older files have higher priority)
# With limited capacity to verify correct sorting
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="time-rule-reverse-true"

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
            "Reverse": true
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/documents"

# Create files with different modification times
# All same size, so time determines priority
# With Reverse=true, OLDER files have HIGHER priority
create_file "$COLD/documents/newest.txt" 100
# newest.txt - current time (lowest priority)

create_file "$COLD/documents/middle.txt" 100
touch -d "3 days ago" "$COLD/documents/middle.txt"

create_file "$COLD/documents/oldest.txt" 100
touch -d "7 days ago" "$COLD/documents/oldest.txt"  # Highest priority

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh --time-style=long-iso {} \; | sort

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# With Reverse=true: older files first (lower timestamp = higher priority)
# Hot capacity: 150KB
# oldest.txt (100KB, 7 days old) should go first
# middle.txt (100KB, 3 days old) would exceed capacity

echo "=== Проверка TimeRule с Reverse=true (старые файлы важнее) ==="

if [[ -f "$HOT/documents/oldest.txt" ]]; then
    echo "✅ oldest.txt (7 дней) на hot - правильный приоритет"
else
    echo "❌ oldest.txt (7 дней) должен быть на hot"
    success=false
fi

if [[ -f "$COLD/documents/middle.txt" ]]; then
    echo "✅ middle.txt (3 дня) на cold - не влезает"
else
    echo "❌ middle.txt (3 дня) должен остаться на cold"
    success=false
fi

if [[ -f "$COLD/documents/newest.txt" ]]; then
    echo "✅ newest.txt (сегодня) на cold - не влезает"
else
    echo "❌ newest.txt (сегодня) должен остаться на cold"
    success=false
fi

echo ""
if $success; then
    echo "✅ TimeRule Reverse=true test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ TimeRule Reverse=true test FAILED"
    test_result false "$TEST_NAME"
fi
