#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="folder-rules-time"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Создаём кастомный storage.json с folder rules для TimeRule
cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 90, "path": "$HOT"},
        {"target": 100, "path": "$COLD"}
    ],
    "FolderRules": [
        {
            "PathPrefix": "documents",
            "Priority": 10,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/documents"

# Создаём файлы с разным временем модификации
create_file "$COLD/documents/old.txt" 10
touch -d "5 days ago" "$COLD/documents/old.txt"

create_file "$COLD/documents/middle.txt" 10
touch -d "2 days ago" "$COLD/documents/middle.txt"

create_file "$COLD/documents/new.txt" 10
# new.txt остаётся с текущим временем

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh --time-style=long-iso {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Все файлы должны быть на hot
for f in documents/old.txt documents/new.txt documents/middle.txt; do
    if ! assert_file_exists "$HOT/$f"; then
        success=false
    fi
done

if ! assert_file_count "$COLD" 0; then
    success=false
fi

test_result "$success" "$TEST_NAME"
