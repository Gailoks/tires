#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="ignore-pattern"

source "$TESTS_DIR/common.sh"

# Инициализация
init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

# Настройка storage.json для теста
# Файлы в папке important НЕ должны перемещаться
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
            "PathPrefix": "important",
            "Priority": 100,
            "RuleType": "Ignore"
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
# Создаём папку important с файлами которые НЕ должны перемещаться
mkdir -p "$COLD/important"
create_file "$COLD/important/file1.txt" 10
create_file "$COLD/important/file2.txt" 15

# Обычные файлы которые ДОЛЖНЫ переместиться
create_file "$COLD/normal1.txt" 200
create_file "$COLD/normal2.txt" 300

echo "📊 Файлы созданы:"
find "$TEST_ROOT" -type f \( -name "*.txt" \) -exec ls -lh {} \;

# Запуск приложения
if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

# Проверки
echo "🔍 Проверка результатов..."
success=true

# Файлы из important должны остаться в cold
if ! assert_file_exists "$COLD/important/file1.txt"; then
    echo "❌ important/file1.txt должен остаться в cold"
    success=false
fi

if ! assert_file_exists "$COLD/important/file2.txt"; then
    echo "❌ important/file2.txt должен остаться в cold"
    success=false
fi

# Файлы из important НЕ должны быть в hot
if ! assert_file_not_exists "$HOT/important/file1.txt"; then
    echo "❌ important/file1.txt не должен быть в hot"
    success=false
fi

if ! assert_file_not_exists "$HOT/important/file2.txt"; then
    echo "❌ important/file2.txt не должен быть в hot"
    success=false
fi

# normal файлы ДОЛЖНЫ быть в hot
if ! assert_file_exists "$HOT/normal1.txt"; then
    echo "❌ normal1.txt должен быть в hot"
    success=false
fi

if ! assert_file_exists "$HOT/normal2.txt"; then
    echo "❌ normal2.txt должен быть в hot"
    success=false
fi

# Проверка количества файлов
important_count=$(find "$COLD/important" -type f | wc -l)
hot_count=$(find "$HOT" -type f -name "*.txt" ! -path "$HOT/tmp/*" | wc -l)

echo "📊 Распределение: important=$important_count, hot=$hot_count"

if [ "$important_count" -ne 2 ]; then
    echo "❌ В important должно быть 2 файла"
    success=false
fi

test_result "$success" "$TEST_NAME"
