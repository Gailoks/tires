#!/usr/bin/env bash
set -euo pipefail

HOT="/mnt/hot"
COLD="/mnt/cold"

# Очистка
rm -rf "$HOT"/* "$COLD"/* || true
mkdir -p "$HOT" "$COLD"

#####################################################
# 1) Создание вложенных директорий и циклического symlink
#####################################################

echo "Создаём вложенные каталоги и циклическую ссылку..."

mkdir -p "$COLD/dirA/dirB/dirC"
LINK="$COLD/dirA/dirB/dirC/loop_link"

# Создаём циклическую ссылку: dirC -> dirA
ln -s ../../../dirA/ $LINK


#####################################################
# 2) Запускаем вашу программу
#####################################################
dotnet run

success=true

#####################################################
# 3) Проверяем: на COLD не должно быть файлов (symlink = ok)
#####################################################

left_files=$(find "$COLD" -type f | wc -l)
if [[ "$left_files" -gt 0 ]]; then
    echo "❌ FAILED: На COLD остались файлы:"
    find "$COLD" -type f
    success=false
fi

#####################################################
# 4) Проверяем: циклический symlink перенесён на HOT
#####################################################

HOT_LINK="$HOT/dirA/dirB/dirC/loop_link"

if [[ ! -L "$HOT_LINK" ]]; then
    echo "❌ FAILED: Символьная ссылка не перенесена: $HOT_LINK"
    success=false
else
    # Проверяем, что ссылка указывает туда же, что и исходная
    cold_target=$(readlink "$COLD/dirA/dirB/dirC/loop_link" || echo "")
    hot_target=$(readlink "$HOT_LINK" || echo "")

    if [[ "$cold_target" != "$hot_target" ]]; then
        echo "❌ FAILED: Перенесённая ссылка указывает на другой путь"
        echo "COLD target: $cold_target"
        echo "HOT target : $hot_target"
        success=false
    fi
fi

#####################################################
# 5) Итог
#####################################################

if $success; then
    echo "✅ Циклический symlink корректно перенесён на HOT"
    exit 0
else
    echo "❌ Тест провален"
    exit 1
fi
