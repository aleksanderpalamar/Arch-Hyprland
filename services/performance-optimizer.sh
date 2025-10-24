#!/bin/bash

# Performance Optimizer - Sistema de otimização de performance
# Implementa cache inteligente, lazy loading, otimização de startup e paralelização

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do Performance Optimizer
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$PROJECT_ROOT/cache"
PERFORMANCE_CONFIG="$PROJECT_ROOT/config/performance.conf"
METRICS_DIR="$PROJECT_ROOT/data/performance"
OPTIMIZATION_LOG="$PROJECT_ROOT/logs/performance.log"

# Estado do sistema de performance
declare -A cache_registry
declare -A lazy_load_registry
declare -A startup_optimizations
declare -A parallel_jobs
is_initialized=false
cache_enabled=true
lazy_loading_enabled=true
parallel_execution_enabled=true

# Configurações de performance
CACHE_TTL=300              # 5 minutos
MAX_CACHE_SIZE=100         # MB
STARTUP_TIMEOUT=30         # segundos
MAX_PARALLEL_JOBS=4        # jobs simultâneos
PRELOAD_CRITICAL=true      # preload componentes críticos

# Inicializar Performance Optimizer
performance_optimizer_init() {
    log_info "[PerformanceOptimizer] Inicializando sistema de otimização..."
    
    # Criar estrutura necessária
    performance_optimizer_create_structure
    
    # Carregar configuração
    performance_optimizer_load_config
    
    # Inicializar cache system
    performance_optimizer_init_cache
    
    # Configurar lazy loading
    performance_optimizer_init_lazy_loading
    
    # Otimizar startup
    performance_optimizer_optimize_startup
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "system.startup" "performance_optimizer_on_startup"
        register_event_handler "component.loaded" "performance_optimizer_track_loading"
        register_event_handler "cache.invalidate" "performance_optimizer_invalidate_cache"
    fi
    
    is_initialized=true
    log_info "[PerformanceOptimizer] Sistema de otimização inicializado"
    return 0
}

# Criar estrutura necessária
performance_optimizer_create_structure() {
    mkdir -p "$CACHE_DIR"/{components,themes,configs,temp}
    mkdir -p "$METRICS_DIR"/{startup,loading,cache}
    mkdir -p "$(dirname "$PERFORMANCE_CONFIG")"
    mkdir -p "$(dirname "$OPTIMIZATION_LOG")"
    
    # Criar configuração padrão se não existir
    if [ ! -f "$PERFORMANCE_CONFIG" ]; then
        performance_optimizer_create_default_config
    fi
}

# Criar configuração padrão
performance_optimizer_create_default_config() {
    cat > "$PERFORMANCE_CONFIG" << 'EOF'
# Performance Optimizer Configuration

# Cache System
CACHE_ENABLED=true
CACHE_TTL=300
MAX_CACHE_SIZE_MB=100
CACHE_COMPRESSION=true
AUTO_CLEANUP_CACHE=true

# Lazy Loading
LAZY_LOADING_ENABLED=true
PRELOAD_CRITICAL_COMPONENTS=true
CRITICAL_COMPONENTS=(
    "hyprland"
    "waybar"
    "wallpaper"
)

# Startup Optimization
OPTIMIZE_STARTUP=true
PARALLEL_COMPONENT_LOADING=true
MAX_PARALLEL_JOBS=4
STARTUP_TIMEOUT=30
BACKGROUND_INITIALIZATION=true

# Performance Monitoring
COLLECT_METRICS=true
BENCHMARK_COMPONENTS=false
PROFILE_MEMORY_USAGE=false
LOG_PERFORMANCE_WARNINGS=true

# Optimization Features
AUTO_GARBAGE_COLLECTION=true
COMPRESS_LARGE_CONFIGS=true
OPTIMIZE_IMAGE_LOADING=true
DEBOUNCE_CONFIG_CHANGES=true
EOF

    log_info "[PerformanceOptimizer] Configuração padrão criada"
}

# Carregar configuração
performance_optimizer_load_config() {
    if [ -f "$PERFORMANCE_CONFIG" ]; then
        source "$PERFORMANCE_CONFIG" 2>/dev/null || {
            log_error "[PerformanceOptimizer] Erro ao carregar configuração"
            return 1
        }
        
        # Aplicar configurações
        cache_enabled="${CACHE_ENABLED:-true}"
        lazy_loading_enabled="${LAZY_LOADING_ENABLED:-true}"
        parallel_execution_enabled="${PARALLEL_COMPONENT_LOADING:-true}"
        
        log_info "[PerformanceOptimizer] Configuração carregada"
    else
        log_warn "[PerformanceOptimizer] Configuração não encontrada, usando valores padrão"
    fi
}

# Inicializar sistema de cache
performance_optimizer_init_cache() {
    if [ "$cache_enabled" = false ]; then
        log_info "[PerformanceOptimizer] Cache desabilitado"
        return 0
    fi
    
    log_info "[PerformanceOptimizer] Inicializando sistema de cache..."
    
    # Limpar cache expirado na inicialização
    performance_optimizer_cleanup_expired_cache
    
    # Verificar tamanho do cache
    performance_optimizer_check_cache_size
    
    log_info "[PerformanceOptimizer] Sistema de cache inicializado"
}

# Cache de componentes
performance_optimizer_cache_component() {
    local component_name="$1"
    local component_data="$2"
    local cache_key="${3:-$component_name}"
    
    if [ "$cache_enabled" = false ]; then
        return 0
    fi
    
    local cache_file="$CACHE_DIR/components/${cache_key}.cache"
    local timestamp="$(date +%s)"
    
    # Criar arquivo de cache com metadata
    {
        echo "# Cache Metadata"
        echo "CACHED_AT=$timestamp"
        echo "TTL=$CACHE_TTL"
        echo "COMPONENT=$component_name"
        echo "# Cache Data"
        echo "$component_data"
    } > "$cache_file"
    
    # Comprimir se habilitado
    if [ "$CACHE_COMPRESSION" = true ]; then
        gzip "$cache_file" && mv "${cache_file}.gz" "$cache_file"
    fi
    
    cache_registry["$cache_key"]="$cache_file"
    log_info "[PerformanceOptimizer] Componente $component_name cacheado"
}

# Recuperar do cache
performance_optimizer_get_from_cache() {
    local cache_key="$1"
    
    if [ "$cache_enabled" = false ]; then
        return 1
    fi
    
    local cache_file="${cache_registry[$cache_key]}"
    
    if [ -z "$cache_file" ] || [ ! -f "$cache_file" ]; then
        return 1
    fi
    
    # Verificar se cache ainda é válido
    if ! performance_optimizer_is_cache_valid "$cache_file"; then
        performance_optimizer_invalidate_cache_entry "$cache_key"
        return 1
    fi
    
    # Extrair dados do cache
    local cache_data
    if [[ "$cache_file" == *.gz ]] || file "$cache_file" | grep -q "gzip"; then
        cache_data="$(zcat "$cache_file" | sed -n '/^# Cache Data$/,$p' | tail -n +2)"
    else
        cache_data="$(sed -n '/^# Cache Data$/,$p' "$cache_file" | tail -n +2)"
    fi
    
    echo "$cache_data"
    log_info "[PerformanceOptimizer] Cache hit para: $cache_key"
    return 0
}

# Verificar se cache é válido
performance_optimizer_is_cache_valid() {
    local cache_file="$1"
    
    # Extrair timestamp do cache
    local cached_at ttl
    if [[ "$cache_file" == *.gz ]] || file "$cache_file" | grep -q "gzip"; then
        cached_at="$(zcat "$cache_file" | grep "^CACHED_AT=" | cut -d'=' -f2)"
        ttl="$(zcat "$cache_file" | grep "^TTL=" | cut -d'=' -f2)"
    else
        cached_at="$(grep "^CACHED_AT=" "$cache_file" | cut -d'=' -f2)"
        ttl="$(grep "^TTL=" "$cache_file" | cut -d'=' -f2)"
    fi
    
    local current_time="$(date +%s)"
    local expiry_time=$((cached_at + ttl))
    
    [ $current_time -lt $expiry_time ]
}

# Limpeza de cache expirado
performance_optimizer_cleanup_expired_cache() {
    log_info "[PerformanceOptimizer] Limpando cache expirado..."
    
    local cleaned_count=0
    
    for cache_file in "$CACHE_DIR"/*/*.cache; do
        if [ -f "$cache_file" ]; then
            if ! performance_optimizer_is_cache_valid "$cache_file"; then
                rm -f "$cache_file"
                ((cleaned_count++))
            fi
        fi
    done
    
    if [ $cleaned_count -gt 0 ]; then
        log_info "[PerformanceOptimizer] $cleaned_count arquivo(s) de cache expirado removidos"
    fi
}

# Verificar tamanho do cache
performance_optimizer_check_cache_size() {
    local cache_size_mb
    cache_size_mb="$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1)"
    
    if [ "$cache_size_mb" -gt "${MAX_CACHE_SIZE_MB:-100}" ]; then
        log_warn "[PerformanceOptimizer] Cache excedeu tamanho máximo (${cache_size_mb}MB)"
        performance_optimizer_cleanup_old_cache
    fi
}

# Limpeza de cache antigo
performance_optimizer_cleanup_old_cache() {
    log_info "[PerformanceOptimizer] Limpando cache antigo..."
    
    # Remover arquivos mais antigos primeiro
    find "$CACHE_DIR" -name "*.cache" -type f -exec ls -t {} + | tail -n +50 | xargs rm -f
    
    log_info "[PerformanceOptimizer] Cache antigo removido"
}

# Invalidar entrada de cache
performance_optimizer_invalidate_cache_entry() {
    local cache_key="$1"
    
    local cache_file="${cache_registry[$cache_key]}"
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        rm -f "$cache_file"
        unset cache_registry["$cache_key"]
        log_info "[PerformanceOptimizer] Cache invalidado: $cache_key"
    fi
}

# Inicializar lazy loading
performance_optimizer_init_lazy_loading() {
    if [ "$lazy_loading_enabled" = false ]; then
        log_info "[PerformanceOptimizer] Lazy loading desabilitado"
        return 0
    fi
    
    log_info "[PerformanceOptimizer] Configurando lazy loading..."
    
    # Registrar componentes para lazy loading
    performance_optimizer_register_lazy_components
    
    # Preload componentes críticos se habilitado
    if [ "$PRELOAD_CRITICAL_COMPONENTS" = true ]; then
        performance_optimizer_preload_critical_components
    fi
    
    log_info "[PerformanceOptimizer] Lazy loading configurado"
}

# Registrar componentes para lazy loading
performance_optimizer_register_lazy_components() {
    local components_dir="$PROJECT_ROOT/components"
    
    if [ ! -d "$components_dir" ]; then
        return 0
    fi
    
    for component_dir in "$components_dir"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            if [ -f "$component_script" ]; then
                lazy_load_registry["$component_name"]="$component_script"
                log_info "[PerformanceOptimizer] Componente registrado para lazy loading: $component_name"
            fi
        fi
    done
}

# Preload componentes críticos
performance_optimizer_preload_critical_components() {
    if [ -n "${CRITICAL_COMPONENTS[*]}" ]; then
        for component in "${CRITICAL_COMPONENTS[@]}"; do
            performance_optimizer_lazy_load_component "$component" &
        done
        wait
        log_info "[PerformanceOptimizer] Componentes críticos precarregados"
    fi
}

# Lazy load componente
performance_optimizer_lazy_load_component() {
    local component_name="$1"
    
    # Verificar se já está carregado no cache
    if performance_optimizer_get_from_cache "$component_name" >/dev/null 2>&1; then
        log_info "[PerformanceOptimizer] Componente $component_name carregado do cache"
        return 0
    fi
    
    local component_script="${lazy_load_registry[$component_name]}"
    
    if [ -z "$component_script" ] || [ ! -f "$component_script" ]; then
        log_error "[PerformanceOptimizer] Script do componente não encontrado: $component_name"
        return 1
    fi
    
    log_info "[PerformanceOptimizer] Carregando componente: $component_name"
    
    # Medir tempo de carregamento
    local start_time="$(date +%s%N)"
    
    # Carregar componente
    local component_data
    if component_data="$(bash "$component_script" init 2>&1)"; then
        local end_time="$(date +%s%N)"
        local load_time=$(((end_time - start_time) / 1000000)) # ms
        
        # Cache do resultado
        performance_optimizer_cache_component "$component_name" "$component_data"
        
        # Registrar métrica
        performance_optimizer_record_metric "component_load" "$component_name" "$load_time"
        
        log_info "[PerformanceOptimizer] Componente $component_name carregado (${load_time}ms)"
        return 0
    else
        log_error "[PerformanceOptimizer] Falha ao carregar componente: $component_name"
        return 1
    fi
}

# Otimizar startup
performance_optimizer_optimize_startup() {
    if [ "$OPTIMIZE_STARTUP" = false ]; then
        log_info "[PerformanceOptimizer] Otimização de startup desabilitada"
        return 0
    fi
    
    log_info "[PerformanceOptimizer] Otimizando startup do sistema..."
    
    # Configurar carregamento paralelo
    if [ "$parallel_execution_enabled" = true ]; then
        performance_optimizer_setup_parallel_loading
    fi
    
    # Configurar inicialização em background
    if [ "$BACKGROUND_INITIALIZATION" = true ]; then
        performance_optimizer_setup_background_init
    fi
    
    log_info "[PerformanceOptimizer] Startup otimizado"
}

# Configurar carregamento paralelo
performance_optimizer_setup_parallel_loading() {
    log_info "[PerformanceOptimizer] Configurando carregamento paralelo..."
    
    # Limitar número de jobs paralelos
    local max_jobs="${MAX_PARALLEL_JOBS:-4}"
    
    startup_optimizations["parallel_jobs"]="$max_jobs"
    startup_optimizations["job_queue"]=""
    
    log_info "[PerformanceOptimizer] Carregamento paralelo configurado (max: $max_jobs jobs)"
}

# Carregar componentes em paralelo
performance_optimizer_parallel_load_components() {
    local components=("$@")
    local max_jobs="${startup_optimizations[parallel_jobs]:-4}"
    local job_count=0
    
    log_info "[PerformanceOptimizer] Carregando ${#components[@]} componente(s) em paralelo..."
    
    for component in "${components[@]}"; do
        # Verificar se atingiu limite de jobs
        if [ $job_count -ge $max_jobs ]; then
            wait # Aguardar jobs atuais terminarem
            job_count=0
        fi
        
        # Iniciar job em background
        performance_optimizer_lazy_load_component "$component" &
        parallel_jobs["$component"]=$!
        ((job_count++))
    done
    
    # Aguardar todos os jobs terminarem
    wait
    
    log_info "[PerformanceOptimizer] Carregamento paralelo concluído"
}

# Configurar inicialização em background
performance_optimizer_setup_background_init() {
    log_info "[PerformanceOptimizer] Configurando inicialização em background..."
    
    # Identificar componentes não críticos para inicialização em background
    local background_components=()
    
    for component in "${!lazy_load_registry[@]}"; do
        local is_critical=false
        
        if [ -n "${CRITICAL_COMPONENTS[*]}" ]; then
            for critical in "${CRITICAL_COMPONENTS[@]}"; do
                if [ "$component" = "$critical" ]; then
                    is_critical=true
                    break
                fi
            done
        fi
        
        if [ "$is_critical" = false ]; then
            background_components+=("$component")
        fi
    done
    
    # Agendar inicialização em background
    if [ ${#background_components[@]} -gt 0 ]; then
        (
            sleep 2 # Aguardar componentes críticos carregarem
            performance_optimizer_parallel_load_components "${background_components[@]}"
        ) &
        
        log_info "[PerformanceOptimizer] ${#background_components[@]} componente(s) agendados para inicialização em background"
    fi
}

# Registrar métrica de performance
performance_optimizer_record_metric() {
    local metric_type="$1"
    local component="$2"
    local value="$3"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    local metrics_file="$METRICS_DIR/${metric_type}.log"
    echo "$timestamp|$component|$value" >> "$metrics_file"
    
    # Manter apenas últimas 1000 entradas
    if [ -f "$metrics_file" ]; then
        tail -n 1000 "$metrics_file" > "$metrics_file.tmp" && \
        mv "$metrics_file.tmp" "$metrics_file"
    fi
}

# Otimizar configurações grandes
performance_optimizer_optimize_large_configs() {
    local config_file="$1"
    local size_threshold="${2:-1048576}" # 1MB
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    local file_size="$(stat -c%s "$config_file" 2>/dev/null)"
    
    if [ "$file_size" -gt "$size_threshold" ]; then
        log_info "[PerformanceOptimizer] Otimizando configuração grande: $config_file"
        
        # Comprimir se não estiver comprimido
        if [ "$COMPRESS_LARGE_CONFIGS" = true ] && ! file "$config_file" | grep -q "gzip"; then
            gzip -c "$config_file" > "${config_file}.gz"
            log_info "[PerformanceOptimizer] Configuração comprimida: ${config_file}.gz"
        fi
        
        # Criar versão otimizada (removendo comentários e espaços)
        local optimized_file="${config_file}.optimized"
        grep -v '^#' "$config_file" | grep -v '^[[:space:]]*$' > "$optimized_file"
        
        log_info "[PerformanceOptimizer] Versão otimizada criada: $optimized_file"
    fi
}

# Debounce para mudanças de configuração
performance_optimizer_debounce_config_change() {
    local config_name="$1"
    local callback="$2"
    local debounce_time="${3:-1}" # 1 segundo padrão
    
    local debounce_file="/tmp/debounce_${config_name}"
    
    # Cancelar timer anterior se existir
    if [ -f "$debounce_file" ]; then
        local old_pid="$(cat "$debounce_file")"
        kill "$old_pid" 2>/dev/null || true
    fi
    
    # Iniciar novo timer
    (
        sleep "$debounce_time"
        "$callback"
        rm -f "$debounce_file"
    ) &
    
    echo $! > "$debounce_file"
    
    log_info "[PerformanceOptimizer] Debounce configurado para $config_name (${debounce_time}s)"
}

# Garbage collection automático
performance_optimizer_auto_garbage_collection() {
    if [ "$AUTO_GARBAGE_COLLECTION" = false ]; then
        return 0
    fi
    
    log_info "[PerformanceOptimizer] Executando garbage collection..."
    
    # Limpar cache expirado
    performance_optimizer_cleanup_expired_cache
    
    # Limpar arquivos temporários
    find "$CACHE_DIR/temp" -type f -mtime +1 -delete 2>/dev/null || true
    
    # Limpar logs antigos
    find "$METRICS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Limpar processos órfãos
    for job_pid in "${parallel_jobs[@]}"; do
        if ! kill -0 "$job_pid" 2>/dev/null; then
            unset parallel_jobs["$job_pid"]
        fi
    done
    
    log_info "[PerformanceOptimizer] Garbage collection concluído"
}

# Handler para startup do sistema
performance_optimizer_on_startup() {
    local event_data="$1"
    
    log_info "[PerformanceOptimizer] Sistema iniciando, aplicando otimizações..."
    
    # Executar garbage collection
    performance_optimizer_auto_garbage_collection
    
    # Otimizar configurações se necessário
    if [ "$COMPRESS_LARGE_CONFIGS" = true ]; then
        for config_file in "$PROJECT_ROOT"/config/*.conf; do
            if [ -f "$config_file" ]; then
                performance_optimizer_optimize_large_configs "$config_file" &
            fi
        done
        wait
    fi
}

# Rastrear carregamento de componentes
performance_optimizer_track_loading() {
    local event_data="$1"
    local component_name
    component_name="$(echo "$event_data" | grep -o '"component":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$component_name" ]; then
        log_info "[PerformanceOptimizer] Componente carregado: $component_name"
        # Registrar estatística de carregamento
        performance_optimizer_record_metric "component_loaded" "$component_name" "$(date +%s)"
    fi
}

# Handler para invalidação de cache
performance_optimizer_invalidate_cache() {
    local event_data="$1"
    local cache_key
    cache_key="$(echo "$event_data" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$cache_key" ]; then
        performance_optimizer_invalidate_cache_entry "$cache_key"
    else
        # Invalidar todo o cache
        rm -rf "$CACHE_DIR"/*/*.cache 2>/dev/null || true
        declare -A cache_registry=()
        log_info "[PerformanceOptimizer] Todo o cache invalidado"
    fi
}

# Gerar relatório de performance
performance_optimizer_generate_report() {
    local report_file="$METRICS_DIR/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
# Performance Optimizer Report
# Generated: $(date)

## System Status
$(performance_optimizer_status)

## Cache Statistics
EOF

    if [ -d "$CACHE_DIR" ]; then
        local cache_size_mb="$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1)"
        local cache_files="$(find "$CACHE_DIR" -name "*.cache" | wc -l)"
        
        cat >> "$report_file" << EOF
- Cache Size: ${cache_size_mb}MB
- Cache Files: $cache_files
- Cache Hit Rate: $(performance_optimizer_calculate_cache_hit_rate)%
EOF
    fi
    
    cat >> "$report_file" << EOF

## Component Loading Times
EOF

    if [ -f "$METRICS_DIR/component_load.log" ]; then
        echo "Recent loading times:" >> "$report_file"
        tail -n 20 "$METRICS_DIR/component_load.log" | while IFS='|' read -r timestamp component load_time; do
            echo "  - $component: ${load_time}ms ($timestamp)" >> "$report_file"
        done
    fi
    
    echo "Relatório gerado: $report_file"
}

# Calcular taxa de cache hit
performance_optimizer_calculate_cache_hit_rate() {
    # Implementação simplificada - em um sistema real seria mais complexo
    local cache_files="$(find "$CACHE_DIR" -name "*.cache" | wc -l)"
    local total_requests="$(grep -c "Cache hit\|carregado do cache" "$OPTIMIZATION_LOG" 2>/dev/null || echo "0")"
    
    if [ "$total_requests" -gt 0 ]; then
        echo $(((cache_files * 100) / total_requests))
    else
        echo "0"
    fi
}

# Status do Performance Optimizer
performance_optimizer_status() {
    echo "=================================="
    echo "  PERFORMANCE OPTIMIZER STATUS"
    echo "=================================="
    echo ""
    
    echo "🚀 Sistema:"
    echo "  - Status: $([ "$is_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "  - Cache: $([ "$cache_enabled" = true ] && echo "Habilitado" || echo "Desabilitado")"
    echo "  - Lazy Loading: $([ "$lazy_loading_enabled" = true ] && echo "Habilitado" || echo "Desabilitado")"
    echo "  - Execução Paralela: $([ "$parallel_execution_enabled" = true ] && echo "Habilitada" || echo "Desabilitada")"
    echo ""
    
    # Estatísticas de cache
    if [ -d "$CACHE_DIR" ]; then
        local cache_size_mb="$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1)"
        local cache_files="$(find "$CACHE_DIR" -name "*.cache" | wc -l)"
        
        echo "💾 Cache:"
        echo "  - Tamanho: ${cache_size_mb}MB"
        echo "  - Arquivos: $cache_files"
        echo "  - Componentes em cache: ${#cache_registry[@]}"
    fi
    
    echo ""
    
    # Estatísticas de lazy loading
    echo "⚡ Lazy Loading:"
    echo "  - Componentes registrados: ${#lazy_load_registry[@]}"
    echo "  - Jobs paralelos ativos: ${#parallel_jobs[@]}"
    
    echo ""
}

# Health check do Performance Optimizer
performance_optimizer_health_check() {
    local health_issues=0
    
    # Verificar estrutura
    if [ ! -d "$CACHE_DIR" ]; then
        ((health_issues++))
    fi
    
    if [ ! -d "$METRICS_DIR" ]; then
        ((health_issues++))
    fi
    
    # Verificar se cache não está muito grande
    if [ -d "$CACHE_DIR" ]; then
        local cache_size_mb="$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1)"
        if [ "$cache_size_mb" -gt $((MAX_CACHE_SIZE_MB * 2)) ]; then
            ((health_issues++))
        fi
    fi
    
    # Verificar jobs órfãos
    local orphan_jobs=0
    for job_pid in "${parallel_jobs[@]}"; do
        if ! kill -0 "$job_pid" 2>/dev/null; then
            ((orphan_jobs++))
        fi
    done
    
    if [ $orphan_jobs -gt 5 ]; then
        ((health_issues++))
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $health_issues
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            performance_optimizer_init
            ;;
        "cache")
            shift
            case "$1" in
                "component") performance_optimizer_cache_component "$2" "$3" "$4" ;;
                "get") performance_optimizer_get_from_cache "$2" ;;
                "invalidate") performance_optimizer_invalidate_cache_entry "$2" ;;
                "cleanup") performance_optimizer_cleanup_expired_cache ;;
                *) echo "Cache commands: component, get, invalidate, cleanup" ;;
            esac
            ;;
        "lazy-load")
            performance_optimizer_lazy_load_component "$2"
            ;;
        "parallel-load")
            shift
            performance_optimizer_parallel_load_components "$@"
            ;;
        "optimize")
            case "$2" in
                "config") performance_optimizer_optimize_large_configs "$3" ;;
                "startup") performance_optimizer_optimize_startup ;;
                *) echo "Optimize commands: config, startup" ;;
            esac
            ;;
        "gc")
            performance_optimizer_auto_garbage_collection
            ;;
        "report")
            performance_optimizer_generate_report
            ;;
        "status")
            performance_optimizer_status
            ;;
        "health_check")
            performance_optimizer_health_check
            ;;
        "help"|"-h"|"--help")
            echo "Performance Optimizer Commands:"
            echo "  init                           - Inicializar otimizador"
            echo "  cache <cmd> [args]             - Gerenciar cache"
            echo "  lazy-load <component>          - Carregar componente sob demanda"
            echo "  parallel-load <components...>  - Carregar componentes em paralelo"
            echo "  optimize <type> [args]         - Otimizar sistema"
            echo "  gc                             - Garbage collection"
            echo "  report                         - Gerar relatório de performance"
            echo "  status                         - Status do otimizador"
            echo "  health_check                   - Verificar saúde do sistema"
            ;;
        *)
            echo "Ação desconhecida: $action" >&2
            echo "Use 'help' para ver comandos disponíveis" >&2
            exit 1
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi