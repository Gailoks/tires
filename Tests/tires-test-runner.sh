#!/usr/bin/env bash
#===============================================================================
# tires-test-runner - Главный скрипт запуска всех тестов
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Счётчики
PASSED=0
FAILED=0
TOTAL=0

# Список тестов для запуска
TESTS_TO_RUN=()

show_help() {
    cat << EOF
${BLUE}tires-test-runner${NC} - Система автоматического тестирования tires

${YELLOW}Использование:${NC}
    $0 [OPTIONS] [TEST_NAMES...]

${YELLOW}Опции:${NC}
    --list, -l      Показать список всех доступных тестов
    --help, -h      Показать эту справку
    --verbose, -v   Включить подробный вывод

EOF
}

list_tests() {
    echo -e "${BLUE}Доступные тесты:${NC}\n"
    
    for test_dir in "$SCRIPT_DIR"/*/; do
        if [[ -d "$test_dir" ]]; then
            local test_name
            test_name=$(basename "$test_dir")
            
            for sub_dir in "$test_dir"/*/; do
                if [[ -d "$sub_dir" ]] && [[ -f "$sub_dir/test.sh" ]]; then
                    local sub_name
                    sub_name=$(basename "$sub_dir")
                    echo -e "  ✅ ${GREEN}$test_name/$sub_name${NC}"
                fi
            done
            
            if [[ -f "$test_dir/test.sh" ]]; then
                echo -e "  ✅ ${GREEN}$test_name${NC}"
            fi
        fi
    done
}

check_dependencies() {
    if ! command -v dotnet &> /dev/null; then
        echo -e "${RED}❌ Отсутствует dotnet${NC}"
        exit 1
    fi
}

check_build() {
    echo -e "${BLUE}🔨 Проверка сборки проекта...${NC}"
    if ! dotnet build "$PROJECT_DIR/tires.csproj" > /dev/null 2>&1; then
        echo -e "${RED}❌ Ошибка сборки проекта${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Сборка успешна${NC}"
}

run_test() {
    local test_name="$1"
    local test_script
    
    if [[ -f "$SCRIPT_DIR/$test_name/test.sh" ]]; then
        test_script="$SCRIPT_DIR/$test_name/test.sh"
    elif [[ -f "$SCRIPT_DIR/${test_name}/test.sh" ]]; then
        test_script="$SCRIPT_DIR/${test_name}/test.sh"
    else
        echo -e "${RED}❌ Тест '$test_name' не найден${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    TOTAL=$((TOTAL + 1))
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}▶️  Запуск теста:${NC} ${GREEN}$test_name${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    chmod +x "$test_script"
    
    if PROJECT_DIR="$PROJECT_DIR" bash "$test_script"; then
        PASSED=$((PASSED + 1))
        return 0
    else
        FAILED=$((FAILED + 1))
        return 1
    fi
}

discover_tests() {
    local tests=()
    
    for test_dir in "$SCRIPT_DIR"/*/; do
        if [[ -d "$test_dir" ]]; then
            local test_name
            test_name=$(basename "$test_dir")
            
            local has_subtests=false
            for sub_dir in "$test_dir"/*/; do
                if [[ -d "$sub_dir" ]] && [[ -f "$sub_dir/test.sh" ]]; then
                    has_subtests=true
                    local sub_name
                    sub_name=$(basename "$sub_dir")
                    tests+=("$test_name/$sub_name")
                fi
            done
            
            if ! $has_subtests && [[ -f "$test_dir/test.sh" ]]; then
                tests+=("$test_name")
            fi
        fi
    done
    
    printf '%s\n' "${tests[@]}"
}

print_summary() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Результаты тестов${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Всего тестов:  ${YELLOW}$TOTAL${NC}"
    echo -e "✅ Пройдено:   ${GREEN}$PASSED${NC}"
    echo -e "❌ Провалено:   ${RED}$FAILED${NC}"
    echo ""
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 Все тесты пройдены!${NC}"
        return 0
    else
        echo -e "${RED}⚠️  Некоторые тесты не пройдены${NC}"
        return 1
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --list|-l)
                list_tests
                exit 0
                ;;
            --verbose|-v)
                set -x
                shift
                ;;
            *)
                TESTS_TO_RUN+=("$1")
                shift
                ;;
        esac
    done
    
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  tires - Automated Test Runner         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    check_dependencies
    check_build
    
    if [[ ${#TESTS_TO_RUN[@]} -eq 0 ]]; then
        echo -e "${BLUE}🔍 Поиск доступных тестов...${NC}"
        mapfile -t TESTS_TO_RUN < <(discover_tests)
        echo -e "Найдено тестов: ${#TESTS_TO_RUN[@]}"
    fi
    
    for test in "${TESTS_TO_RUN[@]}"; do
        run_test "$test" || true
    done
    
    print_summary
    exit $?
}

main "$@"
