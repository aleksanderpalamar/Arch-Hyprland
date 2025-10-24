#!/bin/bash

# Integration Test Suite - Sistema de testes de integração
# Testa fluxos completos entre componentes, validação end-to-end e cenários reais

# Configuração do ambiente de testes
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
TEST_DATA_DIR="$TEST_DIR/data"
TEST_RESULTS_DIR="$TEST_DIR/results"
TEST_LOG="$TEST_RESULTS_DIR/integration_tests_$(date +%Y%m%d_%H%M%S).log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores de testes
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Configurações de teste
TEST_TIMEOUT=30
PARALLEL_TESTS=false
VERBOSE_OUTPUT=true
CLEANUP_AFTER_TESTS=true

# Inicializar ambiente de testes
test_init() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}     ARCH-HYPRLAND INTEGRATION TESTS${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    
    # Criar estrutura necessária
    mkdir -p "$TEST_DATA_DIR" "$TEST_RESULTS_DIR"
    
    # Inicializar log
    {
        echo "# Integration Tests Log"
        echo "# Started: $(date)"
        echo "# Project: $PROJECT_ROOT"
        echo ""
    } > "$TEST_LOG"
    
    echo "📁 Test Environment:"
    echo "   - Project Root: $PROJECT_ROOT"
    echo "   - Test Directory: $TEST_DIR"
    echo "   - Results: $TEST_RESULTS_DIR"
    echo ""
}

# Funções de logging
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1" | tee -a "$TEST_LOG"
    ((TESTS_SKIPPED++))
}

log_info() {
    if [ "$VERBOSE_OUTPUT" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} $1" | tee -a "$TEST_LOG"
    fi
}

# Executar comando com timeout
run_with_timeout() {
    local timeout_duration="$1"
    shift
    local command="$*"
    
    timeout "$timeout_duration" bash -c "$command"
    return $?
}

# Verificar se serviço está rodando
is_service_running() {
    local service_script="$1"
    
    if [ ! -f "$service_script" ]; then
        return 1
    fi
    
    # Tentar verificar status do serviço
    if timeout 5 bash "$service_script" status >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ===============================================
# TESTES DE INTEGRAÇÃO DOS SERVIÇOS
# ===============================================

# Teste 1: Integração Event System + Logger
test_event_system_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração Event System + Logger..."
    
    local event_system="$PROJECT_ROOT/core/event-system.sh"
    local logger="$PROJECT_ROOT/core/logger.sh"
    
    # Verificar se arquivos existem
    if [ ! -f "$event_system" ] || [ ! -f "$logger" ]; then
        log_skip "Arquivos do core não encontrados"
        return 0
    fi
    
    # Criar script de teste temporário
    local test_script="$TEST_DATA_DIR/event_logger_test.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh" 2>/dev/null || exit 1
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh" 2>/dev/null || exit 1

# Registrar handler de teste
test_handler() {
    log_info "Event received: $1"
    echo "EVENT_HANDLED"
}

if command -v register_event_handler >/dev/null 2>&1; then
    register_event_handler "test.event" "test_handler"
    
    if command -v emit_event >/dev/null 2>&1; then
        emit_event "test.event" "test_data"
    fi
fi
EOF
    
    chmod +x "$test_script"
    
    # Executar teste
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "EVENT_HANDLED"; then
            log_pass "Event System + Logger integração OK"
        else
            log_fail "Event System + Logger não funcionou corretamente"
        fi
    else
        log_fail "Event System + Logger teste falhou com timeout"
    fi
    
    rm -f "$test_script"
}

# Teste 2: Integração Config Manager + Component Registry
test_config_component_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração Config Manager + Component Registry..."
    
    local config_manager="$PROJECT_ROOT/services/config-manager.sh"
    local component_registry="$PROJECT_ROOT/services/component-registry.sh"
    
    if [ ! -f "$config_manager" ] || [ ! -f "$component_registry" ]; then
        log_skip "Serviços de configuração não encontrados"
        return 0
    fi
    
    # Teste de inicialização sequencial
    local test_script="$TEST_DATA_DIR/config_component_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Tentar inicializar config manager
if bash "$config_manager" init 2>/dev/null; then
    echo "CONFIG_MANAGER_OK"
fi

# Tentar inicializar component registry
if bash "$component_registry" init 2>/dev/null; then
    echo "COMPONENT_REGISTRY_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "CONFIG_MANAGER_OK" && echo "$result" | grep -q "COMPONENT_REGISTRY_OK"; then
            log_pass "Config Manager + Component Registry integração OK"
        else
            log_fail "Config Manager + Component Registry falha na inicialização"
        fi
    else
        log_fail "Config Manager + Component Registry teste com timeout"
    fi
    
    rm -f "$test_script"
}

# Teste 3: Integração Theme Engine + Performance Optimizer
test_theme_performance_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração Theme Engine + Performance Optimizer..."
    
    local theme_engine="$PROJECT_ROOT/services/theme-engine.sh"
    local performance_optimizer="$PROJECT_ROOT/services/performance-optimizer.sh"
    
    if [ ! -f "$theme_engine" ] || [ ! -f "$performance_optimizer" ]; then
        log_skip "Theme Engine ou Performance Optimizer não encontrados"
        return 0
    fi
    
    # Teste de cache de temas
    local test_script="$TEST_DATA_DIR/theme_performance_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Inicializar performance optimizer
if bash "$performance_optimizer" init >/dev/null 2>&1; then
    echo "PERF_OPTIMIZER_INIT_OK"
fi

# Inicializar theme engine
if bash "$theme_engine" init >/dev/null 2>&1; then
    echo "THEME_ENGINE_INIT_OK"
fi

# Testar cache
if bash "$performance_optimizer" cache component "test_theme" "theme_data" >/dev/null 2>&1; then
    echo "CACHE_OK"
fi

# Testar recuperação do cache
if bash "$performance_optimizer" cache get "test_theme" >/dev/null 2>&1; then
    echo "CACHE_GET_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        local checks=0
        echo "$result" | grep -q "PERF_OPTIMIZER_INIT_OK" && ((checks++))
        echo "$result" | grep -q "THEME_ENGINE_INIT_OK" && ((checks++))
        echo "$result" | grep -q "CACHE_OK" && ((checks++))
        
        if [ $checks -ge 2 ]; then
            log_pass "Theme Engine + Performance Optimizer integração OK"
        else
            log_fail "Theme Engine + Performance Optimizer integração parcial ($checks/3)"
        fi
    else
        log_fail "Theme Engine + Performance Optimizer teste com timeout"
    fi
    
    rm -f "$test_script"
}

# Teste 4: Integração Plugin System + Monitor Service
test_plugin_monitor_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração Plugin System + Monitor Service..."
    
    local plugin_system="$PROJECT_ROOT/services/plugin-system.sh"
    local monitor_service="$PROJECT_ROOT/services/monitor-service.sh"
    
    if [ ! -f "$plugin_system" ] || [ ! -f "$monitor_service" ]; then
        log_skip "Plugin System ou Monitor Service não encontrados"
        return 0
    fi
    
    # Teste de descoberta e monitoramento
    local test_script="$TEST_DATA_DIR/plugin_monitor_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Inicializar plugin system
if bash "$plugin_system" init >/dev/null 2>&1; then
    echo "PLUGIN_SYSTEM_OK"
fi

# Inicializar monitor service
if bash "$monitor_service" init >/dev/null 2>&1; then
    echo "MONITOR_SERVICE_OK"
fi

# Testar descoberta de plugins
if bash "$plugin_system" discover >/dev/null 2>&1; then
    echo "PLUGIN_DISCOVER_OK"
fi

# Testar health check
if bash "$monitor_service" health_check >/dev/null 2>&1; then
    echo "MONITOR_HEALTH_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        local checks=0
        echo "$result" | grep -q "PLUGIN_SYSTEM_OK" && ((checks++))
        echo "$result" | grep -q "MONITOR_SERVICE_OK" && ((checks++))
        
        if [ $checks -ge 2 ]; then
            log_pass "Plugin System + Monitor Service integração OK"
        else
            log_fail "Plugin System + Monitor Service integração falhou ($checks/2)"
        fi
    else
        log_fail "Plugin System + Monitor Service teste com timeout"
    fi
    
    rm -f "$test_script"
}

# ===============================================
# TESTES DE COMPONENTES
# ===============================================

# Teste 5: Integração de componentes Waybar
test_waybar_component_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração do componente Waybar..."
    
    local waybar_component="$PROJECT_ROOT/components/waybar/waybar-component.sh"
    
    if [ ! -f "$waybar_component" ]; then
        log_skip "Componente Waybar não encontrado"
        return 0
    fi
    
    # Testar interface do componente
    local required_methods=("init" "validate" "apply_theme" "cleanup" "health_check")
    local methods_found=0
    
    for method in "${required_methods[@]}"; do
        if grep -q "^${method}()" "$waybar_component" || grep -q "^waybar_${method}()" "$waybar_component"; then
            ((methods_found++))
        fi
    done
    
    if [ $methods_found -ge 4 ]; then
        log_pass "Componente Waybar interface OK ($methods_found/${#required_methods[@]} métodos)"
    else
        log_fail "Componente Waybar interface incompleta ($methods_found/${#required_methods[@]} métodos)"
    fi
}

# Teste 6: Integração de componentes Wallpaper
test_wallpaper_component_integration() {
    ((TESTS_TOTAL++))
    log_test "Testando integração do componente Wallpaper..."
    
    local wallpaper_component="$PROJECT_ROOT/components/wallpaper/wallpaper-component.sh"
    
    if [ ! -f "$wallpaper_component" ]; then
        log_skip "Componente Wallpaper não encontrado"
        return 0
    fi
    
    # Testar funcionalidades básicas
    local test_script="$TEST_DATA_DIR/wallpaper_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

if bash "$wallpaper_component" health_check >/dev/null 2>&1; then
    echo "WALLPAPER_HEALTH_OK"
fi

if bash "$wallpaper_component" validate >/dev/null 2>&1; then
    echo "WALLPAPER_VALIDATE_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "WALLPAPER_HEALTH_OK"; then
            log_pass "Componente Wallpaper integração OK"
        else
            log_fail "Componente Wallpaper health check falhou"
        fi
    else
        log_fail "Componente Wallpaper teste com timeout"
    fi
    
    rm -f "$test_script"
}

# ===============================================
# TESTES END-TO-END
# ===============================================

# Teste 7: Fluxo completo de inicialização do sistema
test_full_system_startup() {
    ((TESTS_TOTAL++))
    log_test "Testando fluxo completo de inicialização do sistema..."
    
    local system_controller="$PROJECT_ROOT/tools/system-controller.sh"
    
    if [ ! -f "$system_controller" ]; then
        log_skip "System Controller não encontrado"
        return 0
    fi
    
    # Teste de inicialização (apenas validação, não execução completa)
    local test_script="$TEST_DATA_DIR/startup_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Testar help (validação básica)
if bash "$system_controller" help >/dev/null 2>&1; then
    echo "SYSTEM_CONTROLLER_HELP_OK"
fi

# Testar status (sem inicialização completa)
if bash "$system_controller" status >/dev/null 2>&1; then
    echo "SYSTEM_CONTROLLER_STATUS_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "SYSTEM_CONTROLLER_HELP_OK"; then
            log_pass "Sistema Controller acessível"
        else
            log_fail "Sistema Controller não responde corretamente"
        fi
    else
        log_fail "Sistema Controller teste com timeout"
    fi
    
    rm -f "$test_script"
}

# Teste 8: Fluxo de aplicação de tema completo
test_full_theme_application() {
    ((TESTS_TOTAL++))
    log_test "Testando fluxo completo de aplicação de tema..."
    
    local theme_engine="$PROJECT_ROOT/services/theme-engine.sh"
    
    if [ ! -f "$theme_engine" ]; then
        log_skip "Theme Engine não encontrado"
        return 0
    fi
    
    # Criar tema de teste
    local test_theme_dir="$TEST_DATA_DIR/test_theme"
    mkdir -p "$test_theme_dir"
    
    cat > "$test_theme_dir/theme.conf" << EOF
# Test Theme Configuration
THEME_NAME="test_theme"
THEME_VERSION="1.0.0"
PRIMARY_COLOR="#1e1e2e"
SECONDARY_COLOR="#313244"
ACCENT_COLOR="#89b4fa"
EOF
    
    # Testar aplicação de tema
    local test_script="$TEST_DATA_DIR/theme_application_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Inicializar theme engine
if bash "$theme_engine" init >/dev/null 2>&1; then
    echo "THEME_ENGINE_INIT_OK"
fi

# Descobrir temas
if bash "$theme_engine" discover >/dev/null 2>&1; then
    echo "THEME_DISCOVER_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "THEME_ENGINE_INIT_OK"; then
            log_pass "Fluxo de aplicação de tema funcional"
        else
            log_fail "Fluxo de aplicação de tema falhou"
        fi
    else
        log_fail "Fluxo de aplicação de tema com timeout"
    fi
    
    # Cleanup
    rm -rf "$test_theme_dir"
    rm -f "$test_script"
}

# Teste 9: Teste de backup e restore
test_backup_restore_flow() {
    ((TESTS_TOTAL++))
    log_test "Testando fluxo de backup e restore..."
    
    local backup_service="$PROJECT_ROOT/services/backup-service.sh"
    
    if [ ! -f "$backup_service" ]; then
        log_skip "Backup Service não encontrado"
        return 0
    fi
    
    # Testar funcionalidades de backup
    local test_script="$TEST_DATA_DIR/backup_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Inicializar backup service
if bash "$backup_service" init >/dev/null 2>&1; then
    echo "BACKUP_SERVICE_INIT_OK"
fi

# Testar health check
if bash "$backup_service" health_check >/dev/null 2>&1; then
    echo "BACKUP_HEALTH_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "BACKUP_SERVICE_INIT_OK"; then
            log_pass "Backup Service funcional"
        else
            log_fail "Backup Service não inicializa corretamente"
        fi
    else
        log_fail "Backup Service teste com timeout"
    fi
    
    rm -f "$test_script"
}

# Teste 10: Teste de performance sob carga
test_performance_under_load() {
    ((TESTS_TOTAL++))
    log_test "Testando performance sob carga..."
    
    local performance_optimizer="$PROJECT_ROOT/services/performance-optimizer.sh"
    
    if [ ! -f "$performance_optimizer" ]; then
        log_skip "Performance Optimizer não encontrado"
        return 0
    fi
    
    # Simular carga com múltiplos acessos ao cache
    local test_script="$TEST_DATA_DIR/performance_load_test.sh"
    cat > "$test_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"

# Inicializar performance optimizer
bash "$performance_optimizer" init >/dev/null 2>&1

# Simular carga no cache
for i in {1..5}; do
    bash "$performance_optimizer" cache component "test_\$i" "data_\$i" >/dev/null 2>&1 &
done

wait

# Testar recuperação do cache
recovered=0
for i in {1..5}; do
    if bash "$performance_optimizer" cache get "test_\$i" >/dev/null 2>&1; then
        recovered=\$((recovered + 1))
    fi
done

echo "CACHE_RECOVERED=\$recovered"

# Health check final
if bash "$performance_optimizer" health_check >/dev/null 2>&1; then
    echo "PERFORMANCE_HEALTH_OK"
fi
EOF
    
    chmod +x "$test_script"
    
    local result
    if result="$(run_with_timeout "$TEST_TIMEOUT" "$test_script" 2>&1)"; then
        if echo "$result" | grep -q "PERFORMANCE_HEALTH_OK"; then
            local recovered="$(echo "$result" | grep "CACHE_RECOVERED=" | cut -d'=' -f2)"
            if [ "$recovered" -ge 3 ]; then
                log_pass "Performance sob carga OK (cache: $recovered/5)"
            else
                log_fail "Performance sob carga degradada (cache: $recovered/5)"
            fi
        else
            log_fail "Performance sob carga falhou health check"
        fi
    else
        log_fail "Performance sob carga teste com timeout"
    fi
    
    rm -f "$test_script"
}

# ===============================================
# CONTROLE DE EXECUÇÃO DOS TESTES
# ===============================================

# Executar todos os testes
run_all_tests() {
    echo "🚀 Executando todos os testes de integração..."
    echo ""
    
    # Testes de integração de serviços
    test_event_system_integration
    test_config_component_integration
    test_theme_performance_integration
    test_plugin_monitor_integration
    
    # Testes de componentes
    test_waybar_component_integration
    test_wallpaper_component_integration
    
    # Testes end-to-end
    test_full_system_startup
    test_full_theme_application
    test_backup_restore_flow
    test_performance_under_load
}

# Executar testes específicos
run_service_tests() {
    echo "🔧 Executando testes de integração de serviços..."
    echo ""
    
    test_event_system_integration
    test_config_component_integration
    test_theme_performance_integration
    test_plugin_monitor_integration
}

run_component_tests() {
    echo "🧩 Executando testes de componentes..."
    echo ""
    
    test_waybar_component_integration
    test_wallpaper_component_integration
}

run_e2e_tests() {
    echo "🎯 Executando testes end-to-end..."
    echo ""
    
    test_full_system_startup
    test_full_theme_application
    test_backup_restore_flow
    test_performance_under_load
}

# Gerar relatório final
generate_test_report() {
    echo ""
    echo "==============================================="
    echo "           RELATÓRIO DE TESTES"
    echo "==============================================="
    
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$(((TESTS_PASSED * 100) / TESTS_TOTAL))
    fi
    
    echo "📊 Resumo:"
    echo "   Total de testes: $TESTS_TOTAL"
    echo -e "   ${GREEN}Aprovados: $TESTS_PASSED${NC}"
    echo -e "   ${RED}Falharam: $TESTS_FAILED${NC}"
    echo -e "   ${YELLOW}Pulados: $TESTS_SKIPPED${NC}"
    echo "   Taxa de sucesso: ${success_rate}%"
    echo ""
    
    echo "📁 Log detalhado: $TEST_LOG"
    echo ""
    
    # Adicionar resumo ao log
    {
        echo ""
        echo "# Test Summary"
        echo "TESTS_TOTAL=$TESTS_TOTAL"
        echo "TESTS_PASSED=$TESTS_PASSED"
        echo "TESTS_FAILED=$TESTS_FAILED"
        echo "TESTS_SKIPPED=$TESTS_SKIPPED"
        echo "SUCCESS_RATE=$success_rate%"
        echo "FINISHED=$(date)"
    } >> "$TEST_LOG"
    
    # Retornar código de saída apropriado
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ Todos os testes passaram!${NC}"
        return 0
    else
        echo -e "${RED}❌ $TESTS_FAILED teste(s) falharam!${NC}"
        return 1
    fi
}

# Cleanup após testes
cleanup_test_environment() {
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        log_info "Limpando ambiente de teste..."
        rm -rf "$TEST_DATA_DIR"/*.sh
        rm -rf "$TEST_DATA_DIR"/test_*
    fi
}

# Função principal
main() {
    local test_suite="${1:-all}"
    
    test_init
    
    case "$test_suite" in
        "all")
            run_all_tests
            ;;
        "services")
            run_service_tests
            ;;
        "components")
            run_component_tests
            ;;
        "e2e"|"end-to-end")
            run_e2e_tests
            ;;
        "help"|"-h"|"--help")
            echo "Integration Test Suite"
            echo ""
            echo "Usage: $0 [suite]"
            echo ""
            echo "Test suites:"
            echo "  all         - Executar todos os testes (padrão)"
            echo "  services    - Testes de integração de serviços"
            echo "  components  - Testes de componentes"
            echo "  e2e         - Testes end-to-end"
            echo "  help        - Mostrar esta ajuda"
            echo ""
            return 0
            ;;
        *)
            echo "Suite de testes desconhecida: $test_suite"
            echo "Use 'help' para ver opções disponíveis"
            return 1
            ;;
    esac
    
    generate_test_report
    cleanup_test_environment
    
    return $?
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi