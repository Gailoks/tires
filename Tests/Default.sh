#!/bin/bash
set -euo pipefail

# Пути
TIER1="/mnt/hot"
TIER2="/mnt/cold"
MERGE="/mnt/storage"

FILES=("file1.txt" "file2.txt" "file3.txt")

# 1. Создаем каталоги
sudo mkdir -p "$TIER1" "$TIER2" "$MERGE"

# 2. Файлы во второй тир
for i in "${!FILES[@]}"; do
    echo "file$((i+1))" | sudo tee "$TIER2/${FILES[i]}" > /dev/null
done

# 3. Запуск программы
dotnet run >/dev/null

# 4. Проверка переноса файлов на tier1
success=true
for f in "${FILES[@]}"; do
    if [ ! -f "$TIER1/$f" ]; then
        success=false
        echo "❌ $f не найден в $TIER1"
    fi
    if [ -f "$TIER2/$f" ]; then
        success=false
        echo "❌ $f всё ещё присутствует в $TIER2"
    fi
done

# 5. Финальный статус
if $success; then
    echo "✅ Все файлы успешно перенесены на $TIER1"
else
    echo "❌ Ошибка: файлы не были корректно перенесены"
fi

# 6. Очистка
sudo rm -f "$TIER1/"*.txt
