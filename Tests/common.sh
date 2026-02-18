#!/usr/bin/env bash
# Базовый скрипт тестового окружения
# Предоставляет функции для изолированного запуска тестов

set -euo pipefail

# Таймаут для тестов (в секундах)
TEST_TIMEOUT=${TEST_TIMEOUT:-60}

# Временная директория для теста
TEST_ROOT=""

# PROJECT_DIR передаётся из runner'а
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Loop устройства и файлы образов
LOOP_HOT=""
LOOP_COLD=""
IMG_HOT=""
IMG_COLD=""
MNT_HOT=""
MNT_COLD=""

# Инициализация тестового окружения
init_test_env() {
    local test_name="$1"
    TEST_ROOT=$(mktemp -d -t "tires-test-${test_name}-XXXXXX")
    
    echo "📁 Тестовая директория: $TEST_ROOT"
    
    # Создаём базовую структуру
    mkdir -p "$TEST_ROOT/hot"
    mkdir -p "$TEST_ROOT/cold"
    
    # Создаём временный storage.json
    cat > "$TEST_ROOT/storage.json" << 'EOF'
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        { "target": 90, "path": "HOT_PATH" },
        { "target": 100, "path": "COLD_PATH" }
    ]
}
EOF
}

# Очистка тестового окружения
cleanup_test_env() {
    # Размонтируем и освобождаем loop устройства
    if [[ -n "$MNT_HOT" && -d "$MNT_HOT" ]]; then
        sudo umount -l "$MNT_HOT" 2>/dev/null || true
        rm -rf "$MNT_HOT" 2>/dev/null || true
    fi
    if [[ -n "$MNT_COLD" && -d "$MNT_COLD" ]]; then
        sudo umount -l "$MNT_COLD" 2>/dev/null || true
        rm -rf "$MNT_COLD" 2>/dev/null || true
    fi
    if [[ -n "$LOOP_HOT" && -b "$LOOP_HOT" ]]; then
        sudo losetup -d "$LOOP_HOT" 2>/dev/null || true
    fi
    if [[ -n "$LOOP_COLD" && -b "$LOOP_COLD" ]]; then
        sudo losetup -d "$LOOP_COLD" 2>/dev/null || true
    fi
    if [[ -n "$IMG_HOT" && -f "$IMG_HOT" ]]; then
        rm -f "$IMG_HOT"
    fi
    if [[ -n "$IMG_COLD" && -f "$IMG_COLD" ]]; then
        rm -f "$IMG_COLD"
    fi
    
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT" 2>/dev/null || true
        echo "🧹 Очистка завершена"
    fi
}

# Создание виртуального диска с ограниченным местом
# size_mb - размер в MB
# returns: путь к смонтированной директории
create_virtual_disk() {
    local size_mb="$1"
    local name="$2"
    
    local img_file="$TEST_ROOT/${name}.img"
    local mnt_dir="$TEST_ROOT/${name}_mnt"
    
    # Создаём файл образ
    dd if=/dev/zero of="$img_file" bs=1M count="$size_mb" status=none
    
    # Создаём loop устройство
    local loop_dev
    loop_dev=$(sudo losetup --find --show "$img_file")
    
    # Сохраняем для cleanup
    if [[ "$name" == "hot" ]]; then
        LOOP_HOT="$loop_dev"
        IMG_HOT="$img_file"
        MNT_HOT="$mnt_dir"
    else
        LOOP_COLD="$loop_dev"
        IMG_COLD="$img_file"
        MNT_COLD="$mnt_dir"
    fi
    
    # Форматируем в ext4
    sudo mkfs.ext4 -F -q "$loop_dev"
    
    # Монтируем
    mkdir -p "$mnt_dir"
    sudo mount "$loop_dev" "$mnt_dir"
    
    # Даём права пользователю
    sudo chown "$(whoami)":"$(whoami)" "$mnt_dir"
    
    echo "$mnt_dir"
}

# Настройка storage.json с виртуальными дисками
setup_virtual_storage() {
    local hot_path="$1"
    local cold_path="$2"
    
    sed -i "s|HOT_PATH|$hot_path|g" "$TEST_ROOT/storage.json"
    sed -i "s|COLD_PATH|$cold_path|g" "$TEST_ROOT/storage.json"
}

# Настройка storage.json для теста
configure_storage() {
    local hot_path="$1"
    local cold_path="$2"
    
    sed -i "s|HOT_PATH|$hot_path|g" "$TEST_ROOT/storage.json"
    sed -i "s|COLD_PATH|$cold_path|g" "$TEST_ROOT/storage.json"
}

# Запуск приложения с таймаутом
run_app() {
    local config_path="${1:-$TEST_ROOT/storage.json}"
    local timeout="${2:-$TEST_TIMEOUT}"
    
    echo "▶️  Запуск приложения..."
    echo "   Конфигурация: $config_path"
    echo "   Проект: $PROJECT_DIR"
    
    # Запускаем из директории проекта чтобы storage.json нашёлся относительно
    if ! timeout "$timeout" dotnet run --project "$PROJECT_DIR/tires.csproj" -- "$config_path" > "$TEST_ROOT/output.log" 2>&1; then
        echo "❌ Приложение завершилось с ошибкой или превышен таймаут"
        cat "$TEST_ROOT/output.log"
        return 1
    fi
    
    echo "✅ Приложение завершило работу"
    return 0
}

# Проверка существования файла
assert_file_exists() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "❌ Файл не найден: $path"
        return 1
    fi
    return 0
}

# Проверка отсутствия файла
assert_file_not_exists() {
    local path="$1"
    if [[ -f "$path" ]]; then
        echo "❌ Файл существует (не должен): $path"
        return 1
    fi
    return 0
}

# Проверка количества файлов в директории
assert_file_count() {
    local dir="$1"
    local expected="$2"
    local count
    count=$(find "$dir" -type f | wc -l)
    
    if [[ "$count" -ne "$expected" ]]; then
        echo "❌ Ожидалось файлов: $expected, найдено: $count"
        return 1
    fi
    return 0
}

# Сравнение inode двух файлов (для hardlinks)
assert_same_inode() {
    local file1="$1"
    local file2="$2"
    local inode1 inode2
    
    inode1=$(stat -c %i "$file1")
    inode2=$(stat -c %i "$file2")
    
    if [[ "$inode1" != "$inode2" ]]; then
        echo "❌ Inode не совпадают: $file1 ($inode1) != $file2 ($inode2)"
        return 1
    fi
    return 0
}

# Проверка что symlink указывает на правильный путь
assert_symlink_target() {
    local link="$1"
    local expected_target="$2"
    local actual_target
    
    if [[ ! -L "$link" ]]; then
        echo "❌ Не является symlink: $link"
        return 1
    fi
    
    actual_target=$(readlink "$link")
    
    if [[ "$actual_target" != "$expected_target" ]]; then
        echo "❌ Symlink цель не совпадает: ожидалось '$expected_target', получено '$actual_target'"
        return 1
    fi
    return 0
}

# Создание файла с заданным размером
create_file() {
    local path="$1"
    local size_kb="${2:-1}"
    
    mkdir -p "$(dirname "$path")"
    dd if=/dev/zero of="$path" bs=1K count="$size_kb" 2>/dev/null || true
}

# Вывод результата теста
test_result() {
    local success="$1"
    local test_name="$2"
    
    if $success; then
        echo "✅ $test_name: PASSED"
        cleanup_test_env
        exit 0
    else
        echo "❌ $test_name: FAILED"
        cleanup_test_env
        exit 1
    fi
}

# Trap для очистки при прерывании
trap cleanup_test_env EXIT INT TERM
