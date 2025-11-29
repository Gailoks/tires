#!/usr/bin/env bash
set -euo pipefail

STORAGE="/mnt/storage"
HOT="/mnt/hot"
COLD="/mnt/cold"

rm -rf "$HOT"/* "$COLD"/* || true
mkdir -p "$HOT" "$COLD"

echo "Создаём вложенные каталоги и циклическую ссылку..."

mkdir -p "$COLD/dirA/dirB/dirC"
LINK="$STORAGE/dirA/dirB/dirC/loop_link"

ln -s ../../../dirA/ $LINK

dotnet run

success=true

HOT_LINK="$HOT/dirA/dirB/dirC/loop_link"

if [[ ! -L "$HOT_LINK" ]]; then
    echo "❌ FAILED: Символьная ссылка не перенесена: $HOT_LINK"
    success=false
else
    cold_target=$(readlink "$COLD/dirA/dirB/dirC/loop_link" || echo "")
    hot_target=$(readlink "$HOT_LINK" || echo "")

    if [[ "$cold_target" != "$hot_target" ]]; then
        echo "❌ FAILED: Перенесённая ссылка указывает на другой путь"
        echo "COLD target: $cold_target"
        echo "HOT target : $hot_target"
        success=false
    fi
fi

if $success; then
    echo "✅ Циклический symlink корректно перенесён на HOT"
    exit 0
else
    echo "❌ Тест провален"
    exit 1
fi
