#!/bin/bash

# System Controller - Orquestrador do Sistema Modular Hyprland
# Versão funcional sem POO para compatibilidade

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENTS_DIR="$PROJECT_ROOT/components"
SERVICES_DIR="$PROJECT_ROOT/services"
CONFIG_DIR="$PROJECT_ROOT/config"

# Carregar módulos básicos
source "$PROJECT_ROOT/core/logger.sh" 2>/dev/null || {
    echo "Logger não encontrado, usando fallback" >&2
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

source "$PROJECT_ROOT/core/event-system.sh" 2>/dev/null || {
    echo "Sistema de eventos não encontrado" >&2
    emit_event() { echo "[EVENT] $1: $2"; }
}

# Estado do sistema
declare -A component_states
declare -A component_health

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init"|"initialize")
            system_initialize
            ;;
        "start")
            system_start
            ;;
        "stop")
            system_stop
            ;;
        "restart")
            system_restart
            ;;
        "status")
            system_status
            ;;
        "health")
            system_health_check
            ;;
        "theme")
            local theme_name="${2:-default}"
            apply_theme "$theme_name"
            ;;
        "reload")
            system_reload
            ;;
        "components")
            list_components
            ;;
        "backup")
            create_system_backup
            ;;
        "restore")
            restore_system_backup "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "Ação desconhecida: $action" >&2
            show_help
            exit 1
            ;;
    esac
}

# Inicializar sistema
system_initialize() {
    log_info "[SystemController] Inicializando sistema modular..."
    
    # Verificar estrutura básica
    if [ ! -d "$COMPONENTS_DIR" ]; then
        log_error "Diretório de componentes não encontrado: $COMPONENTS_DIR"
        return 1
    fi
    
    # Registrar componentes disponíveis
    discover_components
    
    # Validar configurações
    validate_system_config
    
    log_info "[SystemController] Sistema inicializado com sucesso"
    return 0
}

# Descobrir componentes disponíveis
discover_components() {
    log_info "[SystemController] Descobrindo componentes..."
    
    for component_dir in "$COMPONENTS_DIR"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            if [ -f "$component_script" ]; then
                component_states["$component_name"]="discovered"
                log_info "[SystemController] Componente descoberto: $component_name"
            else
                log_warn "[SystemController] Componente sem script: $component_name"
            fi
        fi
    done
}

# Validar configuração do sistema
validate_system_config() {
    log_info "[SystemController] Validando configurações do sistema..."
    
    local validation_errors=0
    
    # Verificar componentes essenciais
    local essential_components=("hyprland" "waybar" "rofi")
    
    for component in "${essential_components[@]}"; do
        if [ ! -d "$COMPONENTS_DIR/$component" ]; then
            log_error "[SystemController] Componente essencial não encontrado: $component"
            ((validation_errors++))
        fi
    done
    
    if [ $validation_errors -gt 0 ]; then
        log_error "[SystemController] $validation_errors erros de validação encontrados"
        return 1
    fi
    
    log_info "[SystemController] Validação concluída com sucesso"
    return 0
}

# Iniciar sistema
system_start() {
    log_info "[SystemController] Iniciando sistema modular..."
    
    # Inicializar componentes em ordem
    local start_order=("hyprland" "waybar" "rofi" "wallpaper")
    
    for component in "${start_order[@]}"; do
        start_component "$component"
    done
    
    emit_event "system.started" "{\"timestamp\": \"$(date)\"}"
    log_info "[SystemController] Sistema iniciado com sucesso"
}

# Iniciar componente individual
start_component() {
    local component_name="$1"
    local component_dir="$COMPONENTS_DIR/$component_name"
    local component_script="$component_dir/${component_name}-component.sh"
    
    if [ ! -f "$component_script" ]; then
        log_warn "[SystemController] Script do componente não encontrado: $component_name"
        return 1
    fi
    
    log_info "[SystemController] Iniciando componente: $component_name"
    
    # Executar inicialização do componente
    if bash "$component_script" init >/dev/null 2>&1; then
        component_states["$component_name"]="running"
        log_info "[SystemController] Componente iniciado: $component_name"
    else
        component_states["$component_name"]="failed"
        log_error "[SystemController] Falha ao iniciar componente: $component_name"
    fi
}

# Parar sistema
system_stop() {
    log_info "[SystemController] Parando sistema modular..."
    
    # Parar componentes em ordem reversa
    local stop_order=("wallpaper" "rofi" "waybar" "hyprland")
    
    for component in "${stop_order[@]}"; do
        stop_component "$component"
    done
    
    emit_event "system.stopped" "{\"timestamp\": \"$(date)\"}"
    log_info "[SystemController] Sistema parado"
}

# Parar componente individual
stop_component() {
    local component_name="$1"
    local component_script="$COMPONENTS_DIR/$component_name/${component_name}-component.sh"
    
    if [ -f "$component_script" ]; then
        log_info "[SystemController] Parando componente: $component_name"
        bash "$component_script" cleanup >/dev/null 2>&1
        component_states["$component_name"]="stopped"
    fi
}

# Reiniciar sistema
system_restart() {
    log_info "[SystemController] Reiniciando sistema..."
    system_stop
    sleep 2
    system_start
}

# Status do sistema
system_status() {
    echo "=================================="
    echo "    STATUS DO SISTEMA MODULAR"
    echo "=================================="
    echo ""
    
    # Status geral
    local running_components=0
    local total_components=0
    
    for component in "${!component_states[@]}"; do
        ((total_components++))
        if [ "${component_states[$component]}" = "running" ]; then
            ((running_components++))
        fi
    done
    
    echo "📊 Sistema: $running_components/$total_components componentes ativos"
    echo "📅 Data: $(date)"
    echo ""
    
    # Status por componente
    echo "Componentes:"
    for component in "${!component_states[@]}"; do
        local status="${component_states[$component]}"
        local icon="❓"
        
        case "$status" in
            "running") icon="✅" ;;
            "stopped") icon="🛑" ;;
            "failed") icon="❌" ;;
            "discovered") icon="🔍" ;;
        esac
        
        echo "  $icon $component: $status"
    done
    
    # Se nenhum componente foi descoberto ainda
    if [ ${#component_states[@]} -eq 0 ]; then
        echo "  ℹ️  Executar 'init' primeiro para descobrir componentes"
    fi
    
    echo ""
}

# Verificação de saúde
system_health_check() {
    log_info "[SystemController] Verificando saúde do sistema..."
    
    echo "=================================="
    echo "    VERIFICAÇÃO DE SAÚDE"
    echo "=================================="
    echo ""
    
    local health_score=0
    local max_score=0
    
    # Verificar cada componente
    for component_dir in "$COMPONENTS_DIR"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            ((max_score++))
            
            echo -n "🔍 $component_name: "
            
            if [ -f "$component_script" ]; then
                local health_result
                health_result="$(bash "$component_script" health_check 2>/dev/null || echo "unhealthy")"
                
                if [ "$health_result" = "healthy" ]; then
                    echo "✅ Saudável"
                    ((health_score++))
                    component_health["$component_name"]="healthy"
                else
                    echo "❌ Problema detectado"
                    component_health["$component_name"]="unhealthy"
                fi
            else
                echo "⚠️  Script não encontrado"
                component_health["$component_name"]="missing"
            fi
        fi
    done
    
    echo ""
    echo "📊 Score de Saúde: $health_score/$max_score"
    
    # Recomendações
    if [ $health_score -lt $max_score ]; then
        echo ""
        echo "🔧 Recomendações:"
        for component in "${!component_health[@]}"; do
            local health="${component_health[$component]}"
            case "$health" in
                "unhealthy")
                    echo "  - Verificar configuração do $component"
                    ;;
                "missing")
                    echo "  - Instalar script do componente $component"
                    ;;
            esac
        done
    fi
    
    echo ""
}

# Aplicar tema
apply_theme() {
    local theme_name="$1"
    log_info "[SystemController] Aplicando tema: $theme_name"
    
    echo "🎨 Aplicando tema: $theme_name"
    
    # Aplicar tema em cada componente
    for component_dir in "$COMPONENTS_DIR"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            if [ -f "$component_script" ]; then
                echo "  - Aplicando em $component_name..."
                bash "$component_script" apply_theme "$theme_name" >/dev/null 2>&1
            fi
        fi
    done
    
    emit_event "theme.applied" "{\"theme\": \"$theme_name\", \"timestamp\": \"$(date)\"}"
    echo "✅ Tema aplicado com sucesso"
}

# Recarregar sistema
system_reload() {
    log_info "[SystemController] Recarregando configurações..."
    
    echo "🔄 Recarregando sistema..."
    
    # Recarregar cada componente
    for component_dir in "$COMPONENTS_DIR"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            if [ -f "$component_script" ]; then
                echo "  - Recarregando $component_name..."
                bash "$component_script" reload >/dev/null 2>&1 || true
            fi
        fi
    done
    
    echo "✅ Reload concluído"
}

# Listar componentes
list_components() {
    echo "=================================="
    echo "    COMPONENTES DISPONÍVEIS"
    echo "=================================="
    echo ""
    
    for component_dir in "$COMPONENTS_DIR"/*; do
        if [ -d "$component_dir" ]; then
            local component_name="$(basename "$component_dir")"
            local component_script="$component_dir/${component_name}-component.sh"
            
            echo "📦 $component_name"
            
            # Verificar se tem script
            if [ -f "$component_script" ]; then
                echo "   ✅ Script disponível"
            else
                echo "   ❌ Script não encontrado"
            fi
            
            # Verificar arquivos de configuração
            local config_count="$(find "$component_dir" -maxdepth 2 -name "*.conf" -o -name "*.json*" -o -name "*.rasi" | wc -l)"
            echo "   📄 $config_count arquivo(s) de configuração"
            
            echo ""
        fi
    done
}

# Criar backup do sistema
create_system_backup() {
    log_info "[SystemController] Criando backup do sistema..."
    
    local backup_dir="$PROJECT_ROOT/backups/system_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo "💾 Criando backup em: $backup_dir"
    
    # Backup dos componentes
    if [ -d "$COMPONENTS_DIR" ]; then
        cp -r "$COMPONENTS_DIR" "$backup_dir/"
        echo "  ✅ Componentes salvos"
    fi
    
    # Backup das configurações
    if [ -d "$CONFIG_DIR" ]; then
        cp -r "$CONFIG_DIR" "$backup_dir/"
        echo "  ✅ Configurações salvas"
    fi
    
    # Backup dos serviços
    if [ -d "$SERVICES_DIR" ]; then
        cp -r "$SERVICES_DIR" "$backup_dir/"
        echo "  ✅ Serviços salvos"
    fi
    
    echo "✅ Backup criado: $backup_dir"
}

# Restaurar backup do sistema
restore_system_backup() {
    local backup_path="$1"
    
    if [ -z "$backup_path" ]; then
        echo "Uso: $0 restore <caminho-do-backup>"
        return 1
    fi
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup não encontrado: $backup_path"
        return 1
    fi
    
    log_info "[SystemController] Restaurando backup: $backup_path"
    
    echo "⚠️  ATENÇÃO: Isto irá substituir a configuração atual!"
    read -p "Continuar? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelado"
        return 0
    fi
    
    # Parar sistema primeiro
    system_stop
    
    # Restaurar arquivos
    echo "📥 Restaurando arquivos..."
    
    if [ -d "$backup_path/components" ]; then
        rm -rf "$COMPONENTS_DIR"
        cp -r "$backup_path/components" "$COMPONENTS_DIR"
        echo "  ✅ Componentes restaurados"
    fi
    
    if [ -d "$backup_path/config" ]; then
        rm -rf "$CONFIG_DIR"
        cp -r "$backup_path/config" "$CONFIG_DIR"
        echo "  ✅ Configurações restauradas"
    fi
    
    echo "✅ Restore concluído"
}

# Mostrar ajuda
show_help() {
    echo "System Controller - Orquestrador do Sistema Modular Hyprland"
    echo ""
    echo "Uso: $0 <ação> [argumentos]"
    echo ""
    echo "Ações disponíveis:"
    echo "  init              - Inicializar sistema (descobrir componentes)"
    echo "  start             - Iniciar todos os componentes"
    echo "  stop              - Parar todos os componentes"
    echo "  restart           - Reiniciar sistema"
    echo "  status            - Mostrar status do sistema"
    echo "  health            - Verificar saúde dos componentes"
    echo "  theme <nome>      - Aplicar tema"
    echo "  reload            - Recarregar configurações"
    echo "  components        - Listar componentes disponíveis"
    echo "  backup            - Criar backup do sistema"
    echo "  restore <path>    - Restaurar backup"
    echo "  help              - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 init           # Descobrir componentes"
    echo "  $0 start          # Iniciar sistema"
    echo "  $0 theme dark     # Aplicar tema dark"
    echo "  $0 health         # Verificar saúde"
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi