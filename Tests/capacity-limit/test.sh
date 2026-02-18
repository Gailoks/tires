#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="capacity-limit"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

# Создаём виртуальные диски с чёткими границами
# Hot: 3MB - поместятся только малые файлы (~450KB) + накладные расходы ext4
# Cold: 10MB - поместятся все файлы
echo "📀 Создание виртуальных дисков..."
MNT_HOT=$(create_virtual_disk 3 "hot")
MNT_COLD=$(create_virtual_disk 10 "cold")

echo "💾 Виртуальные диски созданы:"
echo "HOT: $MNT_HOT (3MB)"
echo "COLD: $MNT_COLD (10MB)"

# Проверяем доступное место
hot_free=$(df -B1 "$MNT_HOT" | tail -1 | awk '{print $4}')
cold_free=$(df -B1 "$MNT_COLD" | tail -1 | awk '{print $4}')
echo "HOT свободно: $((hot_free / 1024)) KB"
echo "COLD свободно: $((cold_free / 1024)) KB"

# Настраиваем storage.json
cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$MNT_HOT"},
        {"target": 100, "path": "$MNT_COLD"}
    ]
}
EOF

echo "📝 Создание тестовых файлов на COLD..."

# Создаём файлы на cold
# Малые файлы (должны переместиться на hot первыми)
create_file "$MNT_COLD/small1.bin" 100
create_file "$MNT_COLD/small2.bin" 150
create_file "$MNT_COLD/small3.bin" 200

# Большие файлы (останутся на cold т.к. на hot нет места)
create_file "$MNT_COLD/large1.bin" 400
create_file "$MNT_COLD/large2.bin" 500
create_file "$MNT_COLD/large3.bin" 600
create_file "$MNT_COLD/large4.bin" 700

echo "📊 Файлы созданы:"
ls -lh "$MNT_COLD"/*.bin 2>/dev/null || true

# Проверяем что файлы созданы
cold_count_before=$(find "$MNT_COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true
echo "Всего файлов на COLD: $cold_count_before"

echo "▶️  Запуск приложения..."
if ! run_app "$TEST_ROOT/storage.json"; then
    echo "❌ Приложение завершилось с ошибкой"
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Проверяем общее количество файлов
total_files=$(find "$TEST_ROOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
if [[ "$total_files" -ne 7 ]]; then
    echo "❌ Ожидалось 7 файлов, найдено: $total_files"
    success=false
fi

# Считаем файлы на каждом диске
hot_count=$(find "$MNT_HOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
cold_count=$(find "$MNT_COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true

echo "Распределение: hot=$hot_count, cold=$cold_count"

# Проверяем доступное место на hot
hot_free_after=$(df -B1 "$MNT_HOT" | tail -1 | awk '{print $4}') || true
echo "HOT свободно после: $((hot_free_after / 1024)) KB"

# Малые файлы должны быть на hot (они первые по SizeRule)
small_on_hot=0
for f in small1.bin small2.bin small3.bin; do
    if [[ -f "$MNT_HOT/$f" ]]; then
        echo "✅ $f на hot"
        small_on_hot=$((small_on_hot + 1))
    elif [[ -f "$MNT_COLD/$f" ]]; then
        echo "⚠️  $f остался на cold"
    fi
done

# Большие файлы должны остаться на cold (не хватило места на hot)
large_on_cold=0
for f in large1.bin large2.bin large3.bin large4.bin; do
    if [[ -f "$MNT_COLD/$f" ]]; then
        large_on_cold=$((large_on_cold + 1))
    elif [[ -f "$MNT_HOT/$f" ]]; then
        echo "⚠️  $f перемещён на hot (неожиданно)"
    fi
done
echo "Больших файлов на cold: $large_on_cold/4"

# Проверки
if [[ "$hot_count" -lt 1 ]]; then
    echo "❌ На hot должны быть файлы"
    success=false
fi

if [[ "$small_on_hot" -lt 2 ]]; then
    echo "❌ Минимум 2 малых файла должны быть на hot"
    success=false
fi

if $success; then
    echo "✅ Файлы распределены корректно с учётом места"
else
    echo "❌ Ошибка распределения файлов"
fi

test_result "$success" "$TEST_NAME"
