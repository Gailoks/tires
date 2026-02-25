#!/usr/bin/env bash
#===============================================================================
# Comprehensive Rules Test with Size Constraints
# Tests all rule types (Size, Time, Name, Ignore) with limited capacity
# Verifies correct sorting and tier placement according to rules
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
TEST_NAME="rules-comprehensive"

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
        {
            "PathPrefix": "cache",
            "Priority": 300,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": true
        },
        {
            "PathPrefix": "media",
            "Priority": 200,
            "RuleType": "Size",
            "Reverse": false
        },
        {
            "PathPrefix": "backups",
            "Priority": 100,
            "RuleType": "Time",
            "TimeType": "Modify",
            "Reverse": true
        },
        {
            "PathPrefix": "models",
            "Priority": 1000,
            "RuleType": "Ignore"
        },
        {
            "PathPrefix": "cloud",
            "Priority": 1000,
            "RuleType": "Ignore"
        }
    ]
}
EOF

echo "📝 Создание тестовых файлов..."

# Cache files (Priority 300, TimeRule Reverse=true - старые важнее)
mkdir -p "$COLD/cache"
create_file "$COLD/cache/cache_old.dat" 100
touch -d "10 days ago" "$COLD/cache/cache_old.dat"
create_file "$COLD/cache/cache_new.dat" 100
# cache_new.dat - current time

# Media files (Priority 200, SizeRule Reverse=false - большие важнее)
mkdir -p "$COLD/media"
create_file "$COLD/media/large_video.mp4" 300
create_file "$COLD/media/small_video.mp4" 50
create_file "$COLD/media/medium_video.mp4" 150

# Backups files (Priority 100, TimeRule Reverse=true - старые важнее)
mkdir -p "$COLD/backups"
create_file "$COLD/backups/backup_old.tar" 200
touch -d "7 days ago" "$COLD/backups/backup_old.tar"
create_file "$COLD/backups/backup_new.tar" 200
# backup_new.tar - current time

# Ignored files (should stay on cold)
mkdir -p "$COLD/models"
mkdir -p "$COLD/cloud"
create_file "$COLD/models/model_file.bin" 500
create_file "$COLD/cloud/cloud_file.dat" 300

# Unmatched files (default behavior - sorted by size)
mkdir -p "$COLD/other"
create_file "$COLD/other/file1.bin" 80
create_file "$COLD/other/file2.bin" 120

echo "📊 Файлы созданы:"
find "$COLD" -type f -exec ls -lh --time-style=long-iso {} \; | sort

if ! run_app "$TEST_ROOT/storage.json"; then
    test_result false "$TEST_NAME"
fi

echo ""
echo "🔍 Проверка результатов..."
success=true

# Helper function to check file location
check_file_tier() {
    local file="$1"
    local expected_tier="$2"
    local tier_path=""
    
    case "$expected_tier" in
        hot) tier_path="$HOT" ;;
        warm) tier_path="$WARM" ;;
        cold) tier_path="$COLD" ;;
    esac
    
    if [[ -f "$tier_path/$file" ]]; then
        echo "✅ $file на $expected_tier"
        return 0
    else
        echo "❌ $file должен быть на $expected_tier"
        success=false
        return 1
    fi
}

echo ""
echo "=== Проверка IgnoreRule ==="
# Ignored files should stay on cold
check_file_tier "models/model_file.bin" "cold"
check_file_tier "cloud/cloud_file.dat" "cold"

echo ""
echo "=== Проверка Cache (TimeRule, Reverse=true - старые важнее) ==="
# cache_old.dat (старый) должен быть выше в приоритете чем cache_new.dat
check_file_tier "cache/cache_old.dat" "hot"

echo ""
echo "=== Проверка Media (SizeRule, Reverse=false - большие важнее) ==="
# large_video.mp4 (300KB) должен быть выше чем small_video.mp4 (50KB)
check_file_tier "media/large_video.mp4" "hot"

echo ""
echo "=== Проверка Backups (TimeRule, Reverse=true - старые важнее) ==="
# backup_old.tar (старый) должен быть выше чем backup_new.tar
check_file_tier "backups/backup_old.tar" "hot"

echo ""
echo "=== Статистика распределения ==="
hot_count=$(find "$HOT" -type f -name "*.dat" -o -name "*.mp4" -o -name "*.tar" -o -name "*.bin" 2>/dev/null | wc -l)
warm_count=$(find "$WARM" -type f -name "*.dat" -o -name "*.mp4" -o -name "*.tar" -o -name "*.bin" 2>/dev/null | wc -l)
cold_count=$(find "$COLD" -type f -name "*.dat" -o -name "*.mp4" -o -name "*.tar" -o -name "*.bin" 2>/dev/null | wc -l)

echo "Hot tier: $hot_count файлов"
echo "Warm tier: $warm_count файлов"
echo "Cold tier: $cold_count файлов (включая ignored)"

# Проверка что ignored файлы не переместились
ignored_on_hot=$(find "$HOT" -type f \( -path "*/models/*" -o -path "*/cloud/*" \) 2>/dev/null | wc -l)
if [[ "$ignored_on_hot" -gt 0 ]]; then
    echo "❌ Ignored файлы найдены на hot tier!"
    success=false
else
    echo "✅ Ignored файлы не перемещены"
fi

# Проверка общего количества файлов (без ignored)
movable_count=$((hot_count + warm_count))
expected_movable=9  # cache(2) + media(3) + backups(2) + other(2)
if [[ "$movable_count" -ne "$expected_movable" ]]; then
    echo "⚠️  Ожидалось $expected_movable movable файлов, найдено $movable_count"
fi

echo ""
if $success; then
    echo "✅ Comprehensive rules test PASSED"
    test_result true "$TEST_NAME"
else
    echo "❌ Comprehensive rules test FAILED"
    test_result false "$TEST_NAME"
fi
