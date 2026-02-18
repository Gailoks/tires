#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="default"

source "$TESTS_DIR/common.sh"

# Инициализация
init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Настройка storage.json для теста
cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 90, "path": "$HOT"},
        {"target": 100, "path": "$COLD"}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
create_file "$COLD/file1.test" 10
create_file "$COLD/file2.test" 20
create_file "$COLD/file3.test" 15

echo "📊 Файлы созданы:"
find "$TEST_ROOT" -type f -name "*.test" -exec ls -lh {} \;

# Запуск приложения с явной передачей пути к конфигурации
if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

# Проверки
echo "🔍 Проверка результатов..."
success=true

for f in file1.test file2.test file3.test; do
    if ! assert_file_exists "$HOT/$f"; then
        success=false
    fi
    if ! assert_file_not_exists "$COLD/$f"; then
        success=false
    fi
done

if ! assert_file_count "$HOT" 3; then
    success=false
fi

if ! assert_file_count "$COLD" 0; then
    success=false
fi

test_result "$success" "$TEST_NAME"
