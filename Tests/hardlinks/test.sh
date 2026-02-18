#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NAME="hardlinks"

source "$SCRIPT_DIR/../common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

configure_storage "$HOT" "$COLD"

echo "📝 Создание файлов и жестких ссылок..."

# Создание файлов
for i in {1..3}; do
    echo "hot$i" > "$HOT/file_hot_$i.txt"
    echo "cold$i" > "$COLD/file_cold_$i.txt"
done

# Создание жестких ссылок
for i in {1..3}; do
    ln "$HOT/file_hot_$i.txt" "$HOT/hardlink_hot_$i.txt"
    ln "$COLD/file_cold_$i.txt" "$COLD/hardlink_cold_$i.txt"
done

echo "📊 Файлы и ссылки созданы:"
find "$TEST_ROOT" -type f -exec ls -li {} \;

if ! run_app; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Проверка что все файлы на hot
for i in {1..3}; do
    if ! assert_file_exists "$HOT/file_hot_$i.txt"; then
        success=false
    fi
    if ! assert_file_exists "$HOT/hardlink_hot_$i.txt"; then
        success=false
    fi
    if ! assert_file_exists "$HOT/file_cold_$i.txt"; then
        success=false
    fi
    if ! assert_file_exists "$HOT/hardlink_cold_$i.txt"; then
        success=false
    fi
    
    # Проверка сохранения жестких ссылок (одинаковый inode)
    if ! assert_same_inode "$HOT/file_hot_$i.txt" "$HOT/hardlink_hot_$i.txt"; then
        success=false
    fi
    if ! assert_same_inode "$HOT/file_cold_$i.txt" "$HOT/hardlink_cold_$i.txt"; then
        success=false
    fi
done

# Проверка что cold пуст
if ! assert_file_count "$COLD" 0; then
    success=false
fi

test_result "$success" "$TEST_NAME"
