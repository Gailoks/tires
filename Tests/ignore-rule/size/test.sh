#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="ignore-size"

source "$TESTS_DIR/common.sh"

# Инициализация
init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Настройка storage.json для теста
# Файлы в папке large НЕ должны перемещаться (IgnoreRule на папку)
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
            "PathPrefix": "large",
            "Priority": 100,
            "RuleType": "Ignore"
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
# Создаём папку large с файлами которые НЕ должны перемещаться
mkdir -p "$COLD/large"
create_file "$COLD/large/big1.bin" 500
create_file "$COLD/large/big2.bin" 600

# Обычные файлы которые ДОЛЖНЫ переместиться
create_file "$COLD/small1.bin" 50
create_file "$COLD/small2.bin" 100
create_file "$COLD/medium.bin" 150

echo "📊 Файлы созданы:"
find "$TEST_ROOT" -type f -name "*.bin" -exec ls -lh {} \;

# Запуск приложения
if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

# Проверки
echo "🔍 Проверка результатов..."
success=true

# Файлы из large должны остаться в cold
if ! assert_file_exists "$COLD/large/big1.bin"; then
    echo "❌ large/big1.bin должен остаться в cold"
    success=false
fi

if ! assert_file_exists "$COLD/large/big2.bin"; then
    echo "❌ large/big2.bin должен остаться в cold"
    success=false
fi

# Файлы из large НЕ должны быть в hot
if ! assert_file_not_exists "$HOT/large/big1.bin"; then
    echo "❌ large/big1.bin не должен быть в hot"
    success=false
fi

if ! assert_file_not_exists "$HOT/large/big2.bin"; then
    echo "❌ large/big2.bin не должен быть в hot"
    success=false
fi

# Маленькие файлы ДОЛЖНЫ быть в hot
if ! assert_file_exists "$HOT/small1.bin"; then
    echo "❌ small1.bin должен быть в hot"
    success=false
fi

if ! assert_file_exists "$HOT/small2.bin"; then
    echo "❌ small2.bin должен быть в hot"
    success=false
fi

if ! assert_file_exists "$HOT/medium.bin"; then
    echo "❌ medium.bin должен быть в hot"
    success=false
fi

# Проверка количества файлов
large_count=$(find "$COLD/large" -type f | wc -l)
hot_count=$(find "$HOT" -type f -name "*.bin" ! -path "$HOT/tmp/*" | wc -l)

echo "📊 Распределение: large=$large_count, hot=$hot_count"

if [ "$large_count" -ne 2 ]; then
    echo "❌ В large должно быть 2 файла"
    success=false
fi

test_result "$success" "$TEST_NAME"
