#!/bin/bash
set -euo pipefail

STORAGE="/mnt/storage"
TARGET="/mnt/hot"
TIER1="/mnt/hot"
TIER2="/mnt/cold"
MERGE="/mnt/storage"

FILES=("file1.test" "file2.test" "file3.test")

sudo mkdir -p "$TIER1" "$TIER2" "$MERGE"

for i in "${!FILES[@]}"; do
    echo "file$((i+1))" | sudo tee "$TIER2/${FILES[i]}" > /dev/null
done

dotnet run 

success=true
for f in "${FILES[@]}"; do
    if [ ! -f "$TARGET/$f" ]; then
        success=false
        echo "❌ $f не найден в $TARGET"
    fi
    if [ -f "$TIER2/$f" ]; then
        success=false
        echo "❌ $f всё ещё присутствует в $TIER2"
    fi
done

if $success; then
    echo "✅ Все файлы успешно перенесены на $TARGET"
else
    echo "❌ Ошибка: файлы не были корректно перенесены"
fi

sudo rm -f "$TARGET/"*.test
