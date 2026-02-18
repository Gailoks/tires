#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="bigfiles"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

# Создаём виртуальные диски
# Hot: 4MB - поместятся малые файлы + некоторые большие
# Cold: 8MB - все файлы помещаются
echo "📀 Создание виртуальных дисков..."
MNT_HOT=$(create_virtual_disk 4 "hot")
MNT_COLD=$(create_virtual_disk 8 "cold")

echo "💾 Виртуальные диски созданы:"
echo "HOT: $MNT_HOT (4MB)"
echo "COLD: $MNT_COLD (8MB)"

# Проверяем доступное место
hot_free=$(df -B1 "$MNT_HOT" | tail -1 | awk '{print $4}') || true
cold_free=$(df -B1 "$MNT_COLD" | tail -1 | awk '{print $4}') || true
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

# Все файлы на cold - приложение само решит куда их переместить
# SizeRule сортирует по возрастанию размера
create_file "$MNT_COLD/small1.bin" 100
create_file "$MNT_COLD/small2.bin" 150
create_file "$MNT_COLD/small3.bin" 200
create_file "$MNT_COLD/large1.bin" 400
create_file "$MNT_COLD/large2.bin" 500
create_file "$MNT_COLD/large3.bin" 600
create_file "$MNT_COLD/large4.bin" 700

echo "📊 Файлы созданы:"
echo "Всего файлов: 7 (общий размер: 2650KB)"
ls -lh "$MNT_COLD"/*.bin 2>/dev/null || true

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Проверяем что общее количество файлов корректно
total_files=$(find "$TEST_ROOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
if [[ "$total_files" -ne 7 ]]; then
    echo "❌ Ожидалось 7 файлов, найдено: $total_files"
    success=false
fi

# Считаем файлы на каждом диске
hot_count=$(find "$MNT_HOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
cold_count=$(find "$MNT_COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true

echo "Распределение: hot=$hot_count, cold=$cold_count"

# Малые файлы (100, 150, 200 KB) должны быть на hot т.к. они первые по размеру
small_on_hot=0
for f in small1.bin small2.bin small3.bin; do
    if [[ -f "$MNT_HOT/$f" ]]; then
        echo "✅ $f на hot (корректно)"
        small_on_hot=$((small_on_hot + 1))
    fi
done

if [[ "$hot_count" -lt 1 ]]; then
    echo "❌ На hot должны быть файлы (малые файлы первыми по SizeRule)"
    success=false
fi

if [[ "$small_on_hot" -lt 2 ]]; then
    echo "❌ Минимум 2 малых файла должны быть на hot"
    success=false
fi

if $success; then
    echo "✅ Файлы распределены корректно"
else
    echo "❌ Ошибка распределения файлов"
fi

test_result "$success" "$TEST_NAME"
