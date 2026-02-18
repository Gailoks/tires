#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="multi-tier"

source "$TESTS_DIR/common.sh"

# Инициализация
init_test_env "$TEST_NAME"

# Создаём виртуальные диски с ограничениями
# HOT: 1MB (target 100%) - только маленькие файлы
# WARM: 2MB (target 100%) - средние файлы
# COLD: 5MB (target 100%) - большие файлы
echo "📀 Создание виртуальных дисков..."
HOT_MNT=$(create_virtual_disk 1 "hot")
WARM_MNT=$(create_virtual_disk 2 "warm")
COLD_MNT=$(create_virtual_disk 5 "cold")

echo "💾 Виртуальные диски созданы:"
echo "HOT: $HOT_MNT (~1MB)"
echo "WARM: $WARM_MNT (~2MB)"
echo "COLD: $COLD_MNT (~5MB)"

HOT="$HOT_MNT"
WARM="$WARM_MNT"
COLD="$COLD_MNT"

# Настройка storage.json - все target 100% чтобы использовать всё доступное место
cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT"},
        {"target": 100, "path": "$WARM"},
        {"target": 100, "path": "$COLD"}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
# Создаём файлы на COLD диске
# Маленькие (должны попасть на hot)
create_file "$COLD/small1.bin" 100      # 100KB
create_file "$COLD/small2.bin" 150      # 150KB

# Средние (должны попасть на warm)
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

# Проверяем что файлы распределились по уровням
# Из-за ограничений по месту, файлы сортируются по размеру

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
    echo "❌ Общее количество файлов должно быть 6"
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

test_result "$success" "$TEST_NAME"
