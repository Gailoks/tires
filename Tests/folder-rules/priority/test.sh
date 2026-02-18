#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="folder-rules-priority"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Создаём кастомный storage.json с folder rules
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
            "PathPrefix": "priority",
            "Priority": 10,
            "RuleType": "Size",
            "Reverse": true
        },
        {
            "PathPrefix": "normal",
            "Priority": 5,
            "RuleType": "Size",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/priority"
mkdir -p "$COLD/normal"

# Priority folder - большие файлы должны быть первыми (Reverse: true)
create_file "$COLD/priority/small.txt" 10
create_file "$COLD/priority/large.txt" 100

# Normal folder - маленькие файлы должны быть первыми (Reverse: false)
create_file "$COLD/normal/small.txt" 10
create_file "$COLD/normal/large.txt" 100

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Все файлы должны быть на hot
for f in priority/small.txt priority/large.txt normal/small.txt normal/large.txt; do
    if ! assert_file_exists "$HOT/$f"; then
        success=false
    fi
done

if ! assert_file_count "$COLD" 0; then
    success=false
fi

test_result "$success" "$TEST_NAME"
