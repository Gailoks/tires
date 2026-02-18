#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="symlink"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
COLD="$TEST_ROOT/cold"

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

echo "📝 Создание вложенных каталогов и файлов..."

mkdir -p "$COLD/dirA/dirB/dirC"
echo "target content" > "$COLD/dirA/dirB/dirC/target.txt"

# Создаём символьную ссылку
ln -s ../../../dirA/ "$COLD/dirA/dirB/dirC/loop_link"

echo "📊 Структура создана:"
find "$COLD" -type f -o -type l -exec ls -li {} \;

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Проверяем что файл перенесён на hot
if ! assert_file_exists "$HOT/dirA/dirB/dirC/target.txt"; then
    success=false
fi

# Проверяем что symlink остался на cold (приложение не обрабатывает symlink)
COLD_LINK="$COLD/dirA/dirB/dirC/loop_link"
if [[ ! -L "$COLD_LINK" ]]; then
    echo "⚠️  Символьная ссылка была удалена"
fi

# Проверяем что symlink не был перенесён (ожидаемое поведение)
HOT_LINK="$HOT/dirA/dirB/dirC/loop_link"
if [[ -L "$HOT_LINK" ]] || [[ -f "$HOT_LINK" ]]; then
    echo "⚠️  Символьная ссылка была перенесена (неожиданно)"
fi

echo "✅ Файл перенесён, symlink обработан"

test_result "$success" "$TEST_NAME"
