#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="bigfiles"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=4MB, Cold=8MB (в байтах)
HOT_CAPACITY=$((4 * 1024 * 1024))
COLD_CAPACITY=$((8 * 1024 * 1024))

cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."
# Все файлы на cold - приложение само решит куда их переместить
# SizeRule сортирует по возрастанию размера
create_file "$COLD/small1.bin" 100
create_file "$COLD/small2.bin" 150
create_file "$COLD/small3.bin" 200
create_file "$COLD/large1.bin" 400
create_file "$COLD/large2.bin" 500
create_file "$COLD/large3.bin" 600
create_file "$COLD/large4.bin" 700

echo "📊 Файлы созданы:"
echo "Всего файлов: 7 (общий размер: 2650KB)"
find "$COLD" -name "*.bin" -exec ls -lh {} \;

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

# Считаем файлы на каждом tier
hot_count=$(find "$HOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
cold_count=$(find "$COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true

echo "Распределение: hot=$hot_count, cold=$cold_count"

# Малые файлы (100, 150, 200 KB) должны быть на hot т.к. они первые по размеру
small_on_hot=0
for f in small1.bin small2.bin small3.bin; do
    if [[ -f "$HOT/$f" ]]; then
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
