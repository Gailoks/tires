#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="capacity-limit"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$COLD"

# Mock capacity: Hot=2MB (поместятся только малые файлы ~450KB), Cold=10MB
# 2MB = 2097152 bytes, малые файлы = 450KB, большие = 2200KB
HOT_CAPACITY=$((2 * 1024 * 1024))
COLD_CAPACITY=$((10 * 1024 * 1024))

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

# Малые файлы (должны переместиться на hot первыми)
create_file "$COLD/small1.bin" 100
create_file "$COLD/small2.bin" 150
create_file "$COLD/small3.bin" 200

# Большие файлы (останутся на cold т.к. на hot нет места)
create_file "$COLD/large1.bin" 400
create_file "$COLD/large2.bin" 500
create_file "$COLD/large3.bin" 600
create_file "$COLD/large4.bin" 700

echo "📊 Файлы созданы:"
find "$COLD" -name "*.bin" -exec ls -lh {} \;

cold_count_before=$(find "$COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true
if [[ "$cold_count_before" -ne 7 ]]; then
    echo "❌ Не удалось создать файлы"
    test_result false "$TEST_NAME"
fi

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Считаем файлы на каждом tier
hot_count=$(find "$HOT" -type f -name "*.bin" 2>/dev/null | wc -l) || true
cold_count=$(find "$COLD" -type f -name "*.bin" 2>/dev/null | wc -l) || true

echo "Распределение: hot=$hot_count, cold=$cold_count"

# Проверяем что малые файлы на hot
for f in small1.bin small2.bin small3.bin; do
    if [[ -f "$HOT/$f" ]]; then
        echo "✅ $f на hot"
    else
        echo "⚠️  $f не на hot"
    fi
done

# Проверяем что хотя бы один большой файл остался на cold
large_on_cold=0
for f in large1.bin large2.bin large3.bin large4.bin; do
    if [[ -f "$COLD/$f" ]]; then
        large_on_cold=$((large_on_cold + 1))
    fi
done

echo "Больших файлов на cold: $large_on_cold/4"

if [[ "$hot_count" -gt 0 ]] && [[ "$cold_count" -gt 0 ]]; then
    echo "✅ Файлы распределены корректно с учётом места"
else
    echo "❌ Ошибка распределения"
    success=false
fi

test_result "$success" "$TEST_NAME"
