#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NAME="folders"

source "$SCRIPT_DIR/../common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

configure_storage "$HOT" "$COLD"

echo "📝 Создание вложенной структуры файлов..."

for i in {1..3}; do
    mkdir -p "$COLD/level1_$i/level2_$i/level3_$i"
    echo "data $i" > "$COLD/level1_$i/level2_$i/level3_$i/file_$i.txt"
done

echo "📊 Структура создана:"
find "$COLD" -type f -exec ls -lh {} \;

if ! run_app; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Проверка что на cold не осталось файлов
left_files=$(find "$COLD" -type f | wc -l)
if [[ "$left_files" -gt 0 ]]; then
    echo "❌ На COLD осталось файлов: $left_files"
    find "$COLD" -type f
    success=false
fi

# Проверка что все файлы на hot с сохранением структуры
for i in {1..3}; do
    file="$HOT/level1_$i/level2_$i/level3_$i/file_$i.txt"
    if ! assert_file_exists "$file"; then
        success=false
    fi
done

test_result "$success" "$TEST_NAME"
