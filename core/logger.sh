#!/bin/bash

# Sistema de Logging Estruturado
# Fornece funcionalidades de log com diferentes níveis e formatação

# Configurações padrão de logging
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-/tmp/hypr-system.log}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"  # 10MB
LOG_BACKUP_COUNT="${LOG_BACKUP_COUNT:-3}"
LOG_TO_CONSOLE="${LOG_TO_CONSOLE:-true}"
LOG_TO_FILE="${LOG_TO_FILE:-true}"
LOG_WITH_COLOR="${LOG_WITH_COLOR:-true}"

# Níveis de log (numéricos para comparação)
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# Cores para console
declare -A LOG_COLORS=(
    ["DEBUG"]="\033[0;36m"    # Cyan
    ["INFO"]="\033[0;32m"     # Green  
    ["WARN"]="\033[1;33m"     # Yellow
    ["ERROR"]="\033[0;31m"    # Red
    ["FATAL"]="\033[1;31m"    # Bold Red
    ["RESET"]="\033[0m"       # Reset
)

# Função principal de log
log_message() {
    local level="$1"
    shift
    local message="$*"
    
    # Verificar se o nível está habilitado
    local current_level_num="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local message_level_num="${LOG_LEVELS[$level]:-1}"
    
    if [ "$message_level_num" -lt "$current_level_num" ]; then
        return 0
    fi
    
    # Preparar timestamp
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local pid="$$"
    
    # Preparar mensagem formatada
    local formatted_message="[$timestamp] [$level] [PID:$pid] $message"
    
    # Log para console
    if [ "$LOG_TO_CONSOLE" = "true" ]; then
        if [ "$LOG_WITH_COLOR" = "true" ]; then
            local color="${LOG_COLORS[$level]}"
            local reset="${LOG_COLORS[RESET]}"
            echo -e "${color}${formatted_message}${reset}" >&2
        else
            echo "$formatted_message" >&2
        fi
    fi
    
    # Log para arquivo
    if [ "$LOG_TO_FILE" = "true" ]; then
        # Verificar rotação de log
        _rotate_log_if_needed
        
        # Escrever no arquivo
        echo "$formatted_message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Funções de conveniência para cada nível
log_debug() {
    log_message "DEBUG" "$@"
}

log_info() {
    log_message "INFO" "$@"
}

log_warn() {
    log_message "WARN" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

log_fatal() {
    log_message "FATAL" "$@"
}

# Função para log estruturado (JSON-like)
log_structured() {
    local level="$1"
    local component="$2"
    local event="$3"
    local data="$4"
    
    local structured_msg="[$component] $event"
    if [ -n "$data" ]; then
        structured_msg="$structured_msg - $data"
    fi
    
    log_message "$level" "$structured_msg"
}

# Rotação de logs
_rotate_log_if_needed() {
    if [ ! -f "$LOG_FILE" ]; then
        # Criar diretório se necessário
        local log_dir="$(dirname "$LOG_FILE")"
        [ ! -d "$log_dir" ] && mkdir -p "$log_dir"
        return 0
    fi
    
    # Verificar tamanho do arquivo
    local file_size="$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)"
    
    if [ "$file_size" -gt "$LOG_MAX_SIZE" ]; then
        _rotate_logs
    fi
}

_rotate_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi
    
    # Rotacionar arquivos existentes
    for ((i=LOG_BACKUP_COUNT-1; i>=1; i--)); do
        local old_file="${LOG_FILE}.${i}"
        local new_file="${LOG_FILE}.$((i+1))"
        
        if [ -f "$old_file" ]; then
            mv "$old_file" "$new_file" 2>/dev/null
        fi
    done
    
    # Mover arquivo atual para .1
    mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null
    
    log_info "Log rotacionado: $LOG_FILE"
}

# Configurar nível de log dinamicamente
set_log_level() {
    local new_level="$1"
    
    if [ -z "${LOG_LEVELS[$new_level]}" ]; then
        log_error "Nível de log inválido: $new_level"
        log_info "Níveis válidos: ${!LOG_LEVELS[*]}"
        return 1
    fi
    
    LOG_LEVEL="$new_level"
    log_info "Nível de log alterado para: $LOG_LEVEL"
}

# Configurar arquivo de log
set_log_file() {
    local new_file="$1"
    
    if [ -z "$new_file" ]; then
        log_error "Caminho do arquivo de log não fornecido"
        return 1
    fi
    
    LOG_FILE="$new_file"
    log_info "Arquivo de log alterado para: $LOG_FILE"
}

# Habilitar/desabilitar log para console
set_console_logging() {
    local enabled="$1"
    
    case "$enabled" in
        "true"|"on"|"1"|"yes")
            LOG_TO_CONSOLE="true"
            ;;
        "false"|"off"|"0"|"no")
            LOG_TO_CONSOLE="false"
            ;;
        *)
            log_error "Valor inválido para console logging: $enabled"
            return 1
            ;;
    esac
    
    log_info "Console logging: $LOG_TO_CONSOLE"
}

# Habilitar/desabilitar log para arquivo
set_file_logging() {
    local enabled="$1"
    
    case "$enabled" in
        "true"|"on"|"1"|"yes")
            LOG_TO_FILE="true"
            ;;
        "false"|"off"|"0"|"no")
            LOG_TO_FILE="false"
            ;;
        *)
            log_error "Valor inválido para file logging: $enabled"
            return 1
            ;;
    esac
    
    log_info "File logging: $LOG_TO_FILE"
}

# Limpar logs antigos
clear_logs() {
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"* 2>/dev/null
        log_info "Logs limpos"
    fi
}

# Mostrar estatísticas dos logs
show_log_stats() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "Arquivo de log não existe: $LOG_FILE"
        return 1
    fi
    
    local file_size="$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)"
    local line_count="$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)"
    
    echo "Estatísticas do Log:"
    echo "  Arquivo: $LOG_FILE"
    echo "  Tamanho: $file_size bytes"
    echo "  Linhas: $line_count"
    echo "  Nível atual: $LOG_LEVEL"
    echo "  Console: $LOG_TO_CONSOLE"
    echo "  Arquivo: $LOG_TO_FILE"
    echo "  Max size: $LOG_MAX_SIZE bytes"
    echo "  Backups: $LOG_BACKUP_COUNT"
    
    # Mostrar últimas linhas
    echo ""
    echo "Últimas 5 linhas:"
    tail -5 "$LOG_FILE" 2>/dev/null || echo "  (nenhuma entrada)"
}

# Função para log de performance
log_perf() {
    local operation="$1"
    local duration="$2"
    local component="${3:-"SYSTEM"}"
    
    log_structured "INFO" "$component" "PERFORMANCE" "operation=$operation duration=${duration}ms"
}

# Função para log de eventos de sistema
log_system_event() {
    local event_type="$1"
    local event_data="$2"
    local component="${3:-"SYSTEM"}"
    
    log_structured "INFO" "$component" "$event_type" "$event_data"
}

# Função para log de erros com stack trace
log_error_with_trace() {
    local error_msg="$1"
    local component="${2:-"SYSTEM"}"
    
    log_error "[$component] $error_msg"
    
    # Adicionar informação de contexto se disponível
    if [ -n "$BASH_SOURCE" ]; then
        log_debug "  Arquivo: ${BASH_SOURCE[1]:-"unknown"}"
        log_debug "  Função: ${FUNCNAME[2]:-"unknown"}"
        log_debug "  Linha: ${BASH_LINENO[1]:-"unknown"}"
    fi
}

# Inicialização do sistema de logging
_init_logging() {
    # Verificar e criar diretório de log se necessário
    local log_dir="$(dirname "$LOG_FILE")"
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null
    fi
    
    # Log de inicialização
    log_info "Sistema de logging inicializado"
    log_debug "Configurações: LEVEL=$LOG_LEVEL FILE=$LOG_FILE CONSOLE=$LOG_TO_CONSOLE"
}

# Auto-inicialização quando o script é carregado
_init_logging

# Exportar funções principais
export -f log_debug log_info log_warn log_error log_fatal
export -f log_structured log_perf log_system_event log_error_with_trace
export -f set_log_level set_log_file set_console_logging set_file_logging
export -f clear_logs show_log_stats