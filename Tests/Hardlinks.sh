#!/usr/bin/env bash
set -euo pipefail

HOT="/mnt/hot"
COLD="/mnt/cold"

# Очистка и создание директорий
rm -rf "$HOT"/* "$COLD"/*

# Создание файлов
for i in {1..3}; do
    echo "hot$i" > "$HOT/file_hot_$i.txt"
    echo "cold$i" > "$COLD/file_cold_$i.txt"
done

# Создание жестких ссылок
for i in {1..3}; do
    ln "$HOT/file_hot_$i.txt" "$HOT/hardlink_hot_$i.txt"
    ln "$COLD/file_cold_$i.txt" "$COLD/hardlink_cold_$i.txt"
done

# Запуск программы
dotnet run >/dev/null

# Проверка результата
success=true
for i in {1..3}; do
    # Проверяем, что hardlink существует и имеет тот же inode, что и исходный файл
    if [[ ! -f "$HOT/hardlink_hot_$i.txt" ]] || [[ $(stat -c %i "$HOT/file_hot_$i.txt") -ne $(stat -c %i "$HOT/hardlink_hot_$i.txt") ]]; then
        success=false
    fi
    if [[ ! -f "$HOT/hardlink_cold_$i.txt" ]] || [[ $(stat -c %i "$HOT/file_cold_$i.txt") -ne $(stat -c %i "$HOT/hardlink_cold_$i.txt") ]]; then
        success=false
    fi
done

# Вывод статуса
if $success; then
    echo "✅ Программа справилась с задачей"
else
    echo "❌ Программа НЕ справилась с задачей"
fi
