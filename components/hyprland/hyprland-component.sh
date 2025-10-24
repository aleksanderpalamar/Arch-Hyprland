#!/bin/bash

# Hyprland Component - Gerencia configurações do Hyprland (Versão Funcional)
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do componente
COMPONENT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CONFIG_FILE="$COMPONENT_DIR/hyprland.conf"

# Inicializar componente
hyprland_init() {
    log_info "[HyprlandComponent] Inicializando componente Hyprland..."
    
    # Verificar se configurações existem
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "[HyprlandComponent] Configuração não encontrada: $CONFIG_FILE"
        return 1
    fi
    
    # Registrar handlers de eventos (se disponível)
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "wallpaper.changed" "hyprland_handle_wallpaper_change"
        register_event_handler "theme.changed" "hyprland_handle_theme_change"
    fi
    
    log_info "[HyprlandComponent] Hyprland inicializado"
    return 0
}

# Validar configuração
hyprland_validate() {
    log_info "[HyprlandComponent] Validando configuração..."
    
    # Verificar arquivos essenciais
    local required_files=("hyprland.conf" "UserConfigs/UserKeybinds.conf")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$COMPONENT_DIR/$file" ]; then
            log_error "[HyprlandComponent] Arquivo obrigatório não encontrado: $file"
            return 1
        fi
    done
    
    return 0
}

# Aplicar tema
hyprland_apply_theme() {
    local theme_name="$1"
    log_info "[HyprlandComponent] Aplicando tema: $theme_name"
    
    # Recarregar Hyprland se estiver rodando
    if pgrep -x "Hyprland" >/dev/null; then
        hyprctl reload 2>/dev/null || {
            log_warn "[HyprlandComponent] Falha ao recarregar Hyprland"
        }
    fi
    
    return 0
}

# Recarregar configuração
hyprland_reload() {
    log_info "[HyprlandComponent] Recarregando configuração Hyprland..."
    
    if pgrep -x "Hyprland" >/dev/null; then
        hyprctl reload 2>/dev/null || {
            log_warn "[HyprlandComponent] Falha ao recarregar Hyprland"
            return 1
        }
    else
        log_info "[HyprlandComponent] Hyprland não está rodando"
    fi
    
    return 0
}

# Limpeza do componente
hyprland_cleanup() {
    log_info "[HyprlandComponent] Limpeza do Hyprland concluída"
    return 0
}

# Verificação de saúde
hyprland_health_check() {
    if [ -f "$CONFIG_FILE" ] && [ -d "$COMPONENT_DIR/UserConfigs" ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    return 0
}

# Handler para mudança de wallpaper
hyprland_handle_wallpaper_change() {
    log_info "[HyprlandComponent] Wallpaper alterado, atualizando hyprpaper"
    
    # Recarregar hyprpaper se configurado
    if [ -f "$COMPONENT_DIR/hyprpaper.conf" ]; then
        pkill hyprpaper 2>/dev/null || true
        sleep 1
        hyprpaper -c "$COMPONENT_DIR/hyprpaper.conf" &
    fi
}

# Handler para mudança de tema
hyprland_handle_theme_change() {
    local event_data="$1"
    log_info "[HyprlandComponent] Tema alterado: $event_data"
    
    # Aplicar configurações de tema específicas
    hyprland_reload
}

# Função principal para roteamento de comandos
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            hyprland_init
            ;;
        "validate")
            hyprland_validate
            ;;
        "apply_theme")
            hyprland_apply_theme "$2"
            ;;
        "reload")
            hyprland_reload
            ;;
        "cleanup")
            hyprland_cleanup
            ;;
        "health_check")
            hyprland_health_check
            ;;
        "help"|"-h"|"--help")
            echo "Hyprland Component Commands:"
            echo "  init          - Inicializar componente"
            echo "  validate      - Validar configuração"
            echo "  apply_theme   - Aplicar tema"
            echo "  reload        - Recarregar Hyprland"
            echo "  cleanup       - Limpeza do componente"
            echo "  health_check  - Verificar saúde"
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
