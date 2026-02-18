#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="multi-tier"

source "$TESTS_DIR/common.sh"

# Инициализация
init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
WARM="$TEST_ROOT/warm"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$WARM" "$COLD"

# Mock capacity: Hot=1MB, Warm=2MB, Cold=5MB
HOT_CAPACITY=$((1 * 1024 * 1024))
WARM_CAPACITY=$((2 * 1024 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$WARM", "MockCapacity": $WARM_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
# Маленькие (должны попасть на hot ~250KB суммарно)
create_file "$COLD/small1.bin" 100      # 100KB
create_file "$COLD/small2.bin" 150      # 150KB

# Средние (должны попасть на warm ~900KB суммарно)
create_file "$COLD/medium1.bin" 400     # 400KB
create_file "$COLD/medium2.bin" 500     # 500KB

# Большие (должны остаться на cold)
create_file "$COLD/large1.bin" 1000     # 1MB
create_file "$COLD/large2.bin" 1500     # 1.5MB

echo "📊 Файлы созданы:"
find "$COLD" -type f -name "*.bin" -exec ls -lh {} \;

# Запуск приложения
if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

# Проверки
echo "🔍 Проверка результатов..."
success=true

# Проверяем распределение по уровням
hot_count=$(find "$HOT" -type f -name "*.bin" | wc -l)
warm_count=$(find "$WARM" -type f -name "*.bin" | wc -l)
cold_count=$(find "$COLD" -type f -name "*.bin" | wc -l)

echo "📊 Распределение: hot=$hot_count, warm=$warm_count, cold=$cold_count"

# Проверяем что хотя бы некоторые файлы переместились
if [ "$hot_count" -eq 0 ] && [ "$warm_count" -eq 0 ]; then
    echo "❌ Файлы не распределились по уровням"
    success=false
fi

# Проверяем что общее количество файлов сохранилось
total=$((hot_count + warm_count + cold_count))
if [ "$total" -ne 6 ]; then
    echo "❌ Общее количество файлов должно быть 6, найдено: $total"
    success=false
fi

# Проверяем что маленькие файлы на hot или warm
small_on_hot=$(find "$HOT" -type f -name "small*.bin" | wc -l)
small_on_warm=$(find "$WARM" -type f -name "small*.bin" | wc -l)
small_total=$((small_on_hot + small_on_warm))

if [ "$small_total" -ne 2 ]; then
    echo "❌ Маленькие файлы должны быть на hot или warm"
    success=false
fi

# Проверяем что большие файлы в основном на cold
large_on_cold=$(find "$COLD" -type f -name "large*.bin" | wc -l)
if [ "$large_on_cold" -lt 1 ]; then
    echo "❌ Хотя бы один большой файл должен остаться на cold"
    success=false
fi

test_result "$success" "$TEST_NAME"
