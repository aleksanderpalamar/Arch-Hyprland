#!/bin/bash

# Monitor Service - Sistema de monitoramento em tempo real
# Monitora saúde dos componentes, performance e recovery automático

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do Monitor Service
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONITOR_CONFIG="$PROJECT_ROOT/config/monitor.conf"
MONITOR_DATA_DIR="$PROJECT_ROOT/data/monitor"
ALERTS_DIR="$MONITOR_DATA_DIR/alerts"
METRICS_DIR="$MONITOR_DATA_DIR/metrics"
MONITOR_LOG="$PROJECT_ROOT/logs/monitor.log"

# Estado do monitor
declare -A monitored_components
declare -A component_health_history
declare -A alert_thresholds
declare -A recovery_actions
is_initialized=false
monitor_daemon_pid=""
check_interval=30

# Inicializar Monitor Service
monitor_service_init() {
    log_info "[MonitorService] Inicializando Monitor Service..."
    
    # Criar estrutura necessária
    monitor_service_create_structure
    
    # Carregar configuração
    monitor_service_load_config
    
    # Descobrir componentes para monitorar
    monitor_service_discover_components
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "component.failure" "monitor_service_handle_failure"
        register_event_handler "system.started" "monitor_service_start_monitoring"
        register_event_handler "system.shutdown" "monitor_service_stop_monitoring"
    fi
    
    is_initialized=true
    log_info "[MonitorService] Monitor Service inicializado"
    return 0
}

# Criar estrutura necessária
monitor_service_create_structure() {
    mkdir -p "$MONITOR_DATA_DIR"/{alerts,metrics,reports}
    mkdir -p "$(dirname "$MONITOR_CONFIG")"
    mkdir -p "$(dirname "$MONITOR_LOG")"
    
    # Criar configuração padrão se não existir
    if [ ! -f "$MONITOR_CONFIG" ]; then
        monitor_service_create_default_config
    fi
}

# Criar configuração padrão
monitor_service_create_default_config() {
    cat > "$MONITOR_CONFIG" << 'EOF'
# Monitor Service Configuration

# Intervalos de verificação (segundos)
CHECK_INTERVAL=30
DEEP_CHECK_INTERVAL=300
ALERT_COOLDOWN=600

# Limites de alertas
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
RESPONSE_TIME_THRESHOLD=5

# Recovery automático
ENABLE_AUTO_RECOVERY=true
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_COOLDOWN=300

# Notificações
ENABLE_NOTIFICATIONS=true
CRITICAL_ONLY=false
NOTIFICATION_METHODS="system,log"

# Componentes monitorados
MONITOR_COMPONENTS=(
    "hyprland"
    "waybar"
    "rofi"
    "wallpaper"
)

# Métricas coletadas
COLLECT_PERFORMANCE=true
COLLECT_RESOURCE_USAGE=true
COLLECT_ERROR_RATES=true
RETENTION_DAYS=7
EOF

    log_info "[MonitorService] Configuração padrão criada"
}

# Carregar configuração
monitor_service_load_config() {
    if [ -f "$MONITOR_CONFIG" ]; then
        source "$MONITOR_CONFIG" 2>/dev/null || {
            log_error "[MonitorService] Erro ao carregar configuração"
            return 1
        }
        check_interval="${CHECK_INTERVAL:-30}"
        log_info "[MonitorService] Configuração carregada"
    else
        log_warn "[MonitorService] Configuração não encontrada, usando valores padrão"
    fi
}

# Descobrir componentes para monitorar
monitor_service_discover_components() {
    log_info "[MonitorService] Descobrindo componentes para monitorar..."
    
    # Adicionar componentes configurados
    if [ -n "${MONITOR_COMPONENTS[*]}" ]; then
        for component in "${MONITOR_COMPONENTS[@]}"; do
            monitor_service_register_component "$component"
        done
    fi
    
    # Auto-descobrir componentes no diretório components/
    for component_dir in "$PROJECT_ROOT/components"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            if [ -x "$component_script" ]; then
                monitor_service_register_component "$component_name" "$component_script"
            fi
        fi
    done
}

# Registrar componente para monitoramento
monitor_service_register_component() {
    local component_name="$1"
    local component_script="${2:-$PROJECT_ROOT/components/$component_name/${component_name}-component.sh}"
    
    if [ -z "$component_name" ]; then
        log_error "[MonitorService] Nome do componente é obrigatório"
        return 1
    fi
    
    monitored_components["$component_name"]="$component_script"
    component_health_history["$component_name"]=""
    
    # Definir limites padrão
    alert_thresholds["$component_name.response_time"]="${RESPONSE_TIME_THRESHOLD:-5}"
    alert_thresholds["$component_name.error_rate"]="10"
    
    # Definir ações de recovery
    recovery_actions["$component_name"]="restart"
    
    log_info "[MonitorService] Componente registrado para monitoramento: $component_name"
    return 0
}

# Iniciar monitoramento daemon
monitor_service_start_monitoring() {
    if [ -n "$monitor_daemon_pid" ] && kill -0 "$monitor_daemon_pid" 2>/dev/null; then
        log_warn "[MonitorService] Monitor daemon já está rodando (PID: $monitor_daemon_pid)"
        return 0
    fi
    
    log_info "[MonitorService] Iniciando daemon de monitoramento..."
    
    # Iniciar daemon em background
    monitor_service_daemon &
    monitor_daemon_pid=$!
    
    # Salvar PID
    echo "$monitor_daemon_pid" > "$MONITOR_DATA_DIR/monitor.pid"
    
    log_info "[MonitorService] Monitor daemon iniciado (PID: $monitor_daemon_pid)"
    return 0
}

# Parar monitoramento daemon
monitor_service_stop_monitoring() {
    if [ -n "$monitor_daemon_pid" ] && kill -0 "$monitor_daemon_pid" 2>/dev/null; then
        log_info "[MonitorService] Parando daemon de monitoramento..."
        kill "$monitor_daemon_pid" 2>/dev/null
        monitor_daemon_pid=""
        rm -f "$MONITOR_DATA_DIR/monitor.pid"
        log_info "[MonitorService] Monitor daemon parado"
    fi
}

# Daemon de monitoramento
monitor_service_daemon() {
    log_info "[MonitorService] Daemon de monitoramento iniciado"
    
    while true; do
        # Verificar se deve continuar rodando
        if [ ! -f "$MONITOR_DATA_DIR/monitor.pid" ]; then
            break
        fi
        
        # Executar verificações de saúde
        monitor_service_health_check_all
        
        # Coletar métricas se habilitado
        if [ "$COLLECT_PERFORMANCE" = true ]; then
            monitor_service_collect_metrics
        fi
        
        # Limpeza de dados antigos
        monitor_service_cleanup_old_data
        
        # Aguardar próximo ciclo
        sleep "$check_interval"
    done
    
    log_info "[MonitorService] Daemon de monitoramento finalizado"
}

# Verificação de saúde de todos os componentes
monitor_service_health_check_all() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local issues_found=0
    
    for component_name in "${!monitored_components[@]}"; do
        local health_result
        health_result="$(monitor_service_check_component_health "$component_name")"
        
        # Registrar no histórico
        monitor_service_record_health "$component_name" "$health_result" "$timestamp"
        
        # Verificar se precisa de ação
        if [ "$health_result" != "healthy" ]; then
            ((issues_found++))
            monitor_service_handle_unhealthy_component "$component_name" "$health_result"
        fi
    done
    
    # Log resumo se houver problemas
    if [ $issues_found -gt 0 ]; then
        log_warn "[MonitorService] $issues_found componente(s) com problemas detectado(s)"
    fi
}

# Verificar saúde de componente específico
monitor_service_check_component_health() {
    local component_name="$1"
    local component_script="${monitored_components[$component_name]}"
    
    if [ -z "$component_script" ]; then
        echo "unknown"
        return 1
    fi
    
    # Tentar executar health check do componente
    local start_time="$(date +%s)"
    local health_result
    
    if [ -x "$component_script" ]; then
        health_result="$(timeout 10 bash "$component_script" health_check 2>/dev/null)"
        local exit_code=$?
        
        # Calcular tempo de resposta
        local end_time="$(date +%s)"
        local response_time=$((end_time - start_time))
        
        # Verificar se excedeu limite de tempo
        local time_threshold="${alert_thresholds["$component_name.response_time"]}"
        if [ "$response_time" -gt "$time_threshold" ]; then
            echo "slow"
            return 2
        fi
        
        # Verificar resultado
        if [ $exit_code -eq 0 ] && [ "$health_result" = "healthy" ]; then
            echo "healthy"
            return 0
        else
            echo "unhealthy"
            return 1
        fi
    else
        echo "no_script"
        return 3
    fi
}

# Registrar saúde no histórico
monitor_service_record_health() {
    local component_name="$1"
    local health_status="$2"
    local timestamp="$3"
    
    # Arquivo de histórico do componente
    local history_file="$METRICS_DIR/${component_name}_health.log"
    
    # Adicionar entrada
    echo "$timestamp|$health_status" >> "$history_file"
    
    # Manter apenas últimas 1000 entradas
    if [ -f "$history_file" ]; then
        tail -n 1000 "$history_file" > "$history_file.tmp" && \
        mv "$history_file.tmp" "$history_file"
    fi
    
    # Atualizar histórico em memória (últimos 10 status)
    local current_history="${component_health_history[$component_name]}"
    component_health_history["$component_name"]="${current_history:0:18}:$health_status"
}

# Tratar componente com problemas
monitor_service_handle_unhealthy_component() {
    local component_name="$1"
    local health_status="$2"
    
    log_warn "[MonitorService] Componente com problemas: $component_name ($health_status)"
    
    # Verificar se já há alerta ativo
    local alert_file="$ALERTS_DIR/${component_name}_alert.flag"
    local current_time="$(date +%s)"
    
    if [ -f "$alert_file" ]; then
        local alert_time="$(cat "$alert_file")"
        local cooldown="${ALERT_COOLDOWN:-600}"
        
        if [ $((current_time - alert_time)) -lt $cooldown ]; then
            # Ainda em cooldown, não fazer nada
            return 0
        fi
    fi
    
    # Criar alerta
    echo "$current_time" > "$alert_file"
    
    # Notificar problema
    monitor_service_send_alert "$component_name" "$health_status"
    
    # Tentar recovery automático se habilitado
    if [ "$ENABLE_AUTO_RECOVERY" = true ]; then
        monitor_service_attempt_recovery "$component_name" "$health_status"
    fi
}

# Enviar alerta
monitor_service_send_alert() {
    local component_name="$1"
    local health_status="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    local alert_message="Componente $component_name com problemas: $health_status"
    
    # Log do alerta
    echo "[$timestamp] ALERT: $alert_message" >> "$MONITOR_LOG"
    log_warn "[MonitorService] ALERTA: $alert_message"
    
    # Notificação do sistema se habilitada
    if [ "$ENABLE_NOTIFICATIONS" = true ]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Monitor Service" "$alert_message" -u critical -i "dialog-warning"
        fi
    fi
    
    # Salvar detalhes do alerta
    local alert_details_file="$ALERTS_DIR/${component_name}_$(date +%Y%m%d_%H%M%S).json"
    cat > "$alert_details_file" << EOF
{
    "component": "$component_name",
    "status": "$health_status",
    "timestamp": "$timestamp",
    "severity": "warning",
    "message": "$alert_message"
}
EOF
}

# Tentar recovery automático
monitor_service_attempt_recovery() {
    local component_name="$1"
    local health_status="$2"
    
    # Verificar histórico de tentativas de recovery
    local recovery_file="$MONITOR_DATA_DIR/${component_name}_recovery.log"
    local current_time="$(date +%s)"
    local max_attempts="${MAX_RECOVERY_ATTEMPTS:-3}"
    local recovery_cooldown="${RECOVERY_COOLDOWN:-300}"
    
    # Contar tentativas recentes
    local recent_attempts=0
    if [ -f "$recovery_file" ]; then
        while read -r attempt_time; do
            if [ $((current_time - attempt_time)) -lt $recovery_cooldown ]; then
                ((recent_attempts++))
            fi
        done < "$recovery_file"
    fi
    
    if [ $recent_attempts -ge $max_attempts ]; then
        log_warn "[MonitorService] Máximo de tentativas de recovery atingido para $component_name"
        return 1
    fi
    
    log_info "[MonitorService] Tentando recovery automático para $component_name..."
    
    # Registrar tentativa
    echo "$current_time" >> "$recovery_file"
    
    # Executar ação de recovery
    local recovery_action="${recovery_actions[$component_name]:-restart}"
    monitor_service_execute_recovery_action "$component_name" "$recovery_action"
    
    # Aguardar e verificar se funcionou
    sleep 5
    local new_health="$(monitor_service_check_component_health "$component_name")"
    
    if [ "$new_health" = "healthy" ]; then
        log_info "[MonitorService] Recovery bem-sucedido para $component_name"
        monitor_service_send_alert "$component_name" "recovery_success"
    else
        log_warn "[MonitorService] Recovery falhou para $component_name"
    fi
}

# Executar ação de recovery
monitor_service_execute_recovery_action() {
    local component_name="$1"
    local action="$2"
    
    local component_script="${monitored_components[$component_name]}"
    
    case "$action" in
        "restart")
            log_info "[MonitorService] Reiniciando componente: $component_name"
            if [ -x "$component_script" ]; then
                bash "$component_script" cleanup 2>/dev/null || true
                sleep 2
                bash "$component_script" init 2>/dev/null || true
            fi
            ;;
        "reload")
            log_info "[MonitorService] Recarregando componente: $component_name"
            if [ -x "$component_script" ]; then
                bash "$component_script" reload 2>/dev/null || true
            fi
            ;;
        "reset")
            log_info "[MonitorService] Resetando componente: $component_name"
            if [ -x "$component_script" ]; then
                bash "$component_script" cleanup 2>/dev/null || true
                sleep 5
                bash "$component_script" init 2>/dev/null || true
            fi
            ;;
        *)
            log_warn "[MonitorService] Ação de recovery desconhecida: $action"
            ;;
    esac
}

# Coletar métricas de performance
monitor_service_collect_metrics() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Métricas do sistema
    if [ "$COLLECT_RESOURCE_USAGE" = true ]; then
        local cpu_usage="$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d ' ')"
        local memory_usage="$(free | grep Mem | awk '{printf("%.1f", ($3/$2) * 100.0)}')"
        local disk_usage="$(df "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | cut -d'%' -f1)"
        
        # Salvar métricas do sistema
        echo "$timestamp|cpu|$cpu_usage" >> "$METRICS_DIR/system_metrics.log"
        echo "$timestamp|memory|$memory_usage" >> "$METRICS_DIR/system_metrics.log"
        echo "$timestamp|disk|$disk_usage" >> "$METRICS_DIR/system_metrics.log"
        
        # Verificar limites
        if [ "${cpu_usage%.*}" -gt "${CPU_THRESHOLD:-80}" ]; then
            monitor_service_send_alert "system" "high_cpu_usage_${cpu_usage}%"
        fi
        
        if [ "${memory_usage%.*}" -gt "${MEMORY_THRESHOLD:-85}" ]; then
            monitor_service_send_alert "system" "high_memory_usage_${memory_usage}%"
        fi
        
        if [ "$disk_usage" -gt "${DISK_THRESHOLD:-90}" ]; then
            monitor_service_send_alert "system" "high_disk_usage_${disk_usage}%"
        fi
    fi
}

# Limpeza de dados antigos
monitor_service_cleanup_old_data() {
    local retention_days="${RETENTION_DAYS:-7}"
    
    # Limpar arquivos de métricas antigos
    find "$METRICS_DIR" -name "*.log" -mtime +"$retention_days" -delete 2>/dev/null || true
    
    # Limpar alertas antigos
    find "$ALERTS_DIR" -name "*.json" -mtime +"$retention_days" -delete 2>/dev/null || true
    find "$ALERTS_DIR" -name "*_alert.flag" -mtime +"$retention_days" -delete 2>/dev/null || true
    
    # Limpar logs de recovery antigos
    find "$MONITOR_DATA_DIR" -name "*_recovery.log" -mtime +"$retention_days" -delete 2>/dev/null || true
}

# Gerar relatório de status
monitor_service_generate_report() {
    local report_file="$MONITOR_DATA_DIR/reports/status_report_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
# Monitor Service Status Report
# Generated: $(date)

## System Overview
$(monitor_service_status)

## Component Health Summary
EOF

    for component_name in "${!monitored_components[@]}"; do
        local current_health="$(monitor_service_check_component_health "$component_name")"
        local history="${component_health_history[$component_name]}"
        
        cat >> "$report_file" << EOF

### $component_name
- Current Status: $current_health
- Recent History: $history
EOF
    done
    
    cat >> "$report_file" << EOF

## Recent Alerts
EOF

    # Adicionar últimos 10 alertas
    find "$ALERTS_DIR" -name "*.json" -newer "$ALERTS_DIR" -exec cat {} \; | tail -n 10 >> "$report_file" 2>/dev/null || true
    
    echo "Relatório gerado: $report_file"
}

# Status do Monitor Service
monitor_service_status() {
    echo "=================================="
    echo "    MONITOR SERVICE STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Serviço:"
    echo "  - Status: $([ "$is_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "  - Daemon: $([ -n "$monitor_daemon_pid" ] && kill -0 "$monitor_daemon_pid" 2>/dev/null && echo "Rodando (PID: $monitor_daemon_pid)" || echo "Parado")"
    echo "  - Intervalo de verificação: ${check_interval}s"
    echo ""
    
    echo "🔍 Componentes monitorados:"
    if [ ${#monitored_components[@]} -eq 0 ]; then
        echo "  - Nenhum componente registrado"
    else
        for component_name in "${!monitored_components[@]}"; do
            local health="$(monitor_service_check_component_health "$component_name")"
            local status_icon="❓"
            case "$health" in
                "healthy") status_icon="✅" ;;
                "unhealthy") status_icon="❌" ;;
                "slow") status_icon="⚠️" ;;
                "no_script") status_icon="📋" ;;
            esac
            echo "  $status_icon $component_name: $health"
        done
    fi
    
    echo ""
    
    # Estatísticas de alertas
    if [ -d "$ALERTS_DIR" ]; then
        local alert_count="$(find "$ALERTS_DIR" -name "*.json" -mtime -1 | wc -l)"
        echo "📊 Alertas (últimas 24h): $alert_count"
    fi
    
    echo ""
}

# Health check do serviço
monitor_service_health_check() {
    local health_issues=0
    
    # Verificar estrutura
    if [ ! -d "$MONITOR_DATA_DIR" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$MONITOR_CONFIG" ]; then
        ((health_issues++))
    fi
    
    # Verificar se daemon está rodando quando deveria
    if [ "$is_initialized" = true ] && [ -z "$monitor_daemon_pid" ]; then
        ((health_issues++))
    fi
    
    # Verificar se há componentes registrados
    if [ ${#monitored_components[@]} -eq 0 ]; then
        ((health_issues++))
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $health_issues
}

# Handler para falhas de componente
monitor_service_handle_failure() {
    local event_data="$1"
    log_info "[MonitorService] Falha de componente detectada: $event_data"
    
    # Extrair nome do componente do evento
    local component_name
    component_name="$(echo "$event_data" | grep -o '"component":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$component_name" ]; then
        monitor_service_handle_unhealthy_component "$component_name" "failure"
    fi
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            monitor_service_init
            ;;
        "start")
            monitor_service_start_monitoring
            ;;
        "stop")
            monitor_service_stop_monitoring
            ;;
        "status")
            monitor_service_status
            ;;
        "check")
            monitor_service_health_check_all
            ;;
        "register")
            monitor_service_register_component "$2" "$3"
            ;;
        "report")
            monitor_service_generate_report
            ;;
        "health_check")
            monitor_service_health_check
            ;;
        "help"|"-h"|"--help")
            echo "Monitor Service Commands:"
            echo "  init                     - Inicializar serviço"
            echo "  start                    - Iniciar monitoramento"
            echo "  stop                     - Parar monitoramento"
            echo "  status                   - Status do serviço"
            echo "  check                    - Verificar todos os componentes"
            echo "  register <nome> [script] - Registrar componente"
            echo "  report                   - Gerar relatório"
            echo "  health_check             - Verificar saúde do serviço"
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