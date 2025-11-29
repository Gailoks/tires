#!/usr/bin/env bash
set -euo pipefail

HOT="/mnt/hot"
COLD="/mnt/cold"

rm -rf "$HOT"/* "$COLD"/*
mkdir -p "$HOT" "$COLD"

echo "📦 Создаём большие файлы"
for i in $(seq 1 10); do
    dd if=/dev/zero of="$HOT/file_hot_$i.bin" bs=1M count=512 status=none
done
for i in $(seq 1 20); do
    dd if=/dev/zero of="$COLD/file_cold_$i.bin" bs=1M count=256 status=none
done

echo "▶ Запуск программы..."
dotnet run

echo "🔍 Проверяем COLD..."
left=$(find "$COLD" -type f -name 'file_cold_*.bin' | wc -l)
if [[ "$left" -gt 0 ]]; then
    echo "❌ TEST BIGFILES FAILED — на COLD осталось $left файлов"
    exit 1
fi

echo "✅ TEST BIGFILES PASSED"
exit 0
