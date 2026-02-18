#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="folder-rules-name"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Создаём кастомный storage.json с folder rules для NameRule
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
            "PathPrefix": "media",
            "Priority": 10,
            "RuleType": "Name",
            "Pattern": ".mp4",
            "Reverse": false
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
mkdir -p "$COLD/media"

create_file "$COLD/media/video1.mp4" 50
create_file "$COLD/media/document.pdf" 100
create_file "$COLD/media/video2.mp4" 30
create_file "$COLD/media/archive.zip" 80

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Все файлы должны быть на hot
for f in media/video1.mp4 media/document.pdf media/video2.mp4 media/archive.zip; do
    if ! assert_file_exists "$HOT/$f"; then
        success=false
    fi
done

if ! assert_file_count "$COLD" 0; then
    success=false
fi

test_result "$success" "$TEST_NAME"
