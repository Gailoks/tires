#!/usr/bin/env bash
set -euo pipefail

HOT="/mnt/hot"
COLD="/mnt/cold"

# Cleanup
rm -rf "$HOT"/* "$COLD"/*
mkdir -p "$HOT" "$COLD"

echo "Creating 10 files of 512M on hot tier"
for i in $(seq 1 10); do
    dd if=/dev/zero of="$HOT/file_hot_$i.bin" bs=1M count=512 status=none
done

echo "Creating 20 files of 256M on cold tier"
for i in $(seq 1 20); do
    dd if=/dev/zero of="$COLD/file_cold_$i.bin" bs=1M count=256 status=none
done

echo "Initial state:"
du -sh "$HOT"/* | sort -h
du -sh "$COLD"/* | sort -h

echo "Running tires program..."
dotnet run

# Check for cold files still on cold tier
COLD_ON_COLD=$(find "$COLD" -type f -name 'file_cold_*.bin' | wc -l)

FAILED=0


if [ "$COLD_ON_COLD" -gt 0 ]; then
    echo "❌ TEST FAILED: $COLD_ON_COLD cold file(s) still on the cold tier!"
    find "$COLD" -type f -name 'file_cold_*.bin'
    FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
    echo "✅ TEST PASSED: Cold tier is empty of cold files."
    exit 0
else
    exit 1
fi

# Cleanup
rm -rf "$HOT"/*
rm -rf "$COLD"/*
