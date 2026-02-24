#!/usr/bin/env bash
#===============================================================================
# Test: Multiple folder rules with size constraints
# Verifies that files from different rules are distributed correctly
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_NAME="dist-multiple-rules"

source "$TESTS_DIR/common.sh"

init_test_env "$TEST_NAME"

HOT="$TEST_ROOT/hot"
WARM="$TEST_ROOT/warm"
COLD="$TEST_ROOT/cold"

mkdir -p "$HOT" "$WARM" "$COLD"

# Mock capacity: Hot=500KB, Warm=1MB, Cold=5MB
HOT_CAPACITY=$((500 * 1024))
WARM_CAPACITY=$((1024 * 1024))
COLD_CAPACITY=$((5 * 1024 * 1024))

# Create config with multiple rules
cat > "$TEST_ROOT/storage.json" << EOF
{
    "IterationLimit": 20,
    "LogLevel": "Warning",
    "TemporaryPath": "tmp",
    "Tiers": [
        {"target": 100, "path": "$HOT", "MockCapacity": $HOT_CAPACITY},
        {"target": 100, "path": "$WARM", "MockCapacity": $WARM_CAPACITY},
        {"target": 100, "path": "$COLD", "MockCapacity": $COLD_CAPACITY}
    ],
    "FolderRules": [
        {"PathPrefix": "videos", "Priority": 100, "RuleType": "Size", "Reverse": true},
        {"PathPrefix": "documents", "Priority": 50, "RuleType": "Size", "Reverse": false},
        {"PathPrefix": "important", "Priority": 200, "RuleType": "Ignore"}
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Videos folder - large files first (Reverse=true)
mkdir -p "$COLD/videos"
create_file "$COLD/videos/vid_large.mp4" 400    # Should go to warm (too big for hot)
create_file "$COLD/videos/vid_medium.mp4" 200   # Should go to hot
create_file "$COLD/videos/vid_small.mp4" 100    # Should go to hot

# Documents folder - small files first (Reverse=false)
mkdir -p "$COLD/documents"
create_file "$COLD/documents/doc_small.txt" 50   # Should go to hot
create_file "$COLD/documents/doc_medium.txt" 150 # Should go to hot/warm
create_file "$COLD/documents/doc_large.txt" 300  # Should go to warm

# Important folder - should be excluded
mkdir -p "$COLD/important"
create_file "$COLD/important/keep_here.txt" 100  # Should stay on cold

# Unmatched files - default size ascending
mkdir -p "$COLD/other"
create_file "$COLD/other/file_small.bin" 75
create_file "$COLD/other/file_medium.bin" 125
create_file "$COLD/other/file_large.bin" 250

echo "📊 Файлы созданы:"
find "$COLD" -name "*.mp4" -o -name "*.txt" -o -name "*.bin" 2>/dev/null | sort | while read f; do
    ls -lh "$f"
done

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo "🔍 Проверка результатов..."
success=true

# Check important files are excluded (stay on cold)
if [[ -f "$COLD/important/keep_here.txt" ]]; then
    echo "✅ Important file excluded correctly"
else
    echo "❌ Important file should stay on cold"
    success=false
fi

# Count files per tier
hot_count=$(find "$HOT" -type f \( -name "*.mp4" -o -name "*.txt" -o -name "*.bin" \) | wc -l)
warm_count=$(find "$WARM" -type f \( -name "*.mp4" -o -name "*.txt" -o -name "*.bin" \) | wc -l)
cold_count=$(find "$COLD" -type f \( -name "*.mp4" -o -name "*.txt" -o -name "*.bin" \) | wc -l)

echo "📊 Distribution: hot=$hot_count, warm=$warm_count, cold=$cold_count"

# Total should be 10 (9 movable + 1 excluded)
total=$((hot_count + warm_count + cold_count))
if [[ "$total" -ne 10 ]]; then
    echo "❌ Expected 10 files total, found $total"
    success=false
fi

# Hot should have small files (capacity ~500KB)
# Expected: vid_small(100) + vid_medium(200) + doc_small(50) + doc_medium(150) = 500KB = ~4 files
if [[ "$hot_count" -lt 2 ]]; then
    echo "❌ Hot tier should have at least 2 small files"
    success=false
fi

# Warm should have medium files
if [[ "$warm_count" -lt 1 ]]; then
    echo "❌ Warm tier should have at least 1 medium file"
    success=false
fi

# Cold should have: important(1) + large files that don't fit
if [[ "$cold_count" -lt 1 ]]; then
    echo "❌ Cold tier should have excluded and overflow files"
    success=false
fi

if $success; then
    echo "✅ Multiple rules test passed"
else
    echo "❌ Multiple rules test failed"
fi

test_result "$success" "$TEST_NAME"
