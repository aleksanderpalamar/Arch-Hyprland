#!/bin/bash

# Waybar Component - Gerenciamento modular da barra de status (Versão Funcional)
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do componente
COMPONENT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CONFIG_PATH="$HOME/.config/waybar"
CURRENT_LAYOUT="default"
CURRENT_THEME="default"
IS_INITIALIZED=false

# Inicializar componente
waybar_init() {
    log_info "[WaybarComponent] Inicializando componente Waybar..."
    
    waybar_create_config_structure
    waybar_validate_config
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "theme.changed" "waybar_handle_theme_change"
        register_event_handler "wallpaper.changed" "waybar_handle_wallpaper_change"
    fi
    
    IS_INITIALIZED=true
    log_info "[WaybarComponent] Waybar inicializado"
    return 0
}

# Criar estrutura de configuração
waybar_create_config_structure() {
    log_info "[WaybarComponent] Criando estrutura de configuração..."
    
    # Criar diretório se não existir
    mkdir -p "$CONFIG_PATH"
    
    # Verificar se configuração já existe
    if [ ! -f "$CONFIG_PATH/config" ] && [ -f "$COMPONENT_DIR/config.jsonc" ]; then
        log_info "[WaybarComponent] Copiando configuração padrão"
        cp "$COMPONENT_DIR/config.jsonc" "$CONFIG_PATH/config"
    fi
    
    if [ ! -f "$CONFIG_PATH/style.css" ] && [ -f "$COMPONENT_DIR/style.css" ]; then
        log_info "[WaybarComponent] Copiando estilo padrão"
        cp "$COMPONENT_DIR/style.css" "$CONFIG_PATH/style.css"
    fi
}

# Validar configuração
waybar_validate() {
    log_info "[WaybarComponent] Validando configuração..."
    
    local required_files=("config.jsonc" "style.css")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$COMPONENT_DIR/$file" ]; then
            log_error "[WaybarComponent] Arquivo obrigatório não encontrado: $file"
            return 1
        fi
    done
    
    # Verificar sintaxe JSON (se jq estiver disponível)
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$COMPONENT_DIR/config.jsonc" 2>/dev/null; then
            log_warn "[WaybarComponent] Configuração JSON pode ter erros de sintaxe"
        fi
    fi
    
    return 0
}

# Verificar se configuração é válida
waybar_validate_config() {
    log_info "[WaybarComponent] Validando configuração do Waybar..."
    
    if [ ! -f "$COMPONENT_DIR/config.jsonc" ]; then
        log_error "[WaybarComponent] config.jsonc não encontrado"
        return 1
    fi
    
    if [ ! -f "$COMPONENT_DIR/style.css" ]; then
        log_error "[WaybarComponent] style.css não encontrado"
        return 1
    fi
    
    log_info "[WaybarComponent] Configuração válida"
    return 0
}

# Iniciar Waybar
waybar_start() {
    log_info "[WaybarComponent] Iniciando Waybar..."
    
    # Parar instância atual se existir
    waybar_stop
    
    # Aguardar um momento
    sleep 1
    
    # Iniciar nova instância
    waybar -c "$COMPONENT_DIR/config.jsonc" -s "$COMPONENT_DIR/style.css" &
    local waybar_pid=$!
    
    # Verificar se iniciou corretamente
    sleep 2
    if kill -0 "$waybar_pid" 2>/dev/null; then
        log_info "[WaybarComponent] Waybar iniciado (PID: $waybar_pid)"
        return 0
    else
        log_error "[WaybarComponent] Falha ao iniciar Waybar"
        return 1
    fi
}

# Parar Waybar
waybar_stop() {
    log_info "[WaybarComponent] Parando Waybar..."
    
    pkill waybar 2>/dev/null || true
    sleep 1
    
    # Força se necessário
    pkill -9 waybar 2>/dev/null || true
    
    log_info "[WaybarComponent] Waybar parado"
    return 0
}

# Recarregar Waybar
waybar_reload() {
    log_info "[WaybarComponent] Recarregando Waybar..."
    
    if pgrep waybar >/dev/null; then
        pkill -SIGUSR2 waybar 2>/dev/null || {
            log_warn "[WaybarComponent] Sinal de reload falhou, reiniciando..."
            waybar_restart
        }
    else
        log_info "[WaybarComponent] Waybar não estava rodando, iniciando..."
        waybar_start
    fi
    
    return 0
}

# Reiniciar Waybar
waybar_restart() {
    log_info "[WaybarComponent] Reiniciando Waybar..."
    waybar_stop
    sleep 1
    waybar_start
}

# Aplicar tema
waybar_apply_theme() {
    local theme_name="${1:-default}"
    log_info "[WaybarComponent] Aplicando tema: $theme_name"
    
    CURRENT_THEME="$theme_name"
    
    # Recarregar para aplicar tema
    waybar_reload
    
    return 0
}

# Definir layout
waybar_set_layout() {
    local layout_name="${1:-default}"
    log_info "[WaybarComponent] Definindo layout: $layout_name"
    
    CURRENT_LAYOUT="$layout_name"
    
    # Recarregar para aplicar layout
    waybar_reload
    
    return 0
}

# Limpeza do componente
waybar_cleanup() {
    log_info "[WaybarComponent] Limpeza do Waybar..."
    waybar_stop
    return 0
}

# Verificação de saúde
waybar_health_check() {
    local health_issues=0
    
    # Verificar arquivos de configuração
    if [ ! -f "$COMPONENT_DIR/config.jsonc" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$COMPONENT_DIR/style.css" ]; then
        ((health_issues++))
    fi
    
    # Verificar se processo está rodando (opcional)
    # if ! pgrep waybar >/dev/null; then
    #     ((health_issues++))
    # fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return 0
}

# Handler para mudança de tema
waybar_handle_theme_change() {
    local event_data="$1"
    log_info "[WaybarComponent] Tema alterado: $event_data"
    
    # Extrair nome do tema do evento (assumindo formato JSON simples)
    local theme_name
    theme_name="$(echo "$event_data" | grep -o '"theme":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$theme_name" ]; then
        waybar_apply_theme "$theme_name"
    fi
}

# Handler para mudança de wallpaper
waybar_handle_wallpaper_change() {
    local event_data="$1"
    log_info "[WaybarComponent] Wallpaper alterado: $event_data"
    
    # Recarregar para pegar novas cores se necessário
    waybar_reload
}

# Obter status do componente
waybar_get_status() {
    echo "=================================="
    echo "    WAYBAR COMPONENT STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Configuração:"
    echo "  - Diretório: $COMPONENT_DIR"
    echo "  - Tema atual: $CURRENT_THEME"
    echo "  - Layout atual: $CURRENT_LAYOUT"
    echo "  - Inicializado: $IS_INITIALIZED"
    echo ""
    
    echo "📁 Arquivos:"
    if [ -f "$COMPONENT_DIR/config.jsonc" ]; then
        echo "  ✅ config.jsonc"
    else
        echo "  ❌ config.jsonc"
    fi
    
    if [ -f "$COMPONENT_DIR/style.css" ]; then
        echo "  ✅ style.css"
    else
        echo "  ❌ style.css"
    fi
    
    echo ""
    echo "🔄 Processo:"
    if pgrep waybar >/dev/null; then
        local waybar_pid="$(pgrep waybar)"
        echo "  ✅ Waybar rodando (PID: $waybar_pid)"
    else
        echo "  ❌ Waybar não está rodando"
    fi
    
    echo ""
}

# Função principal para roteamento de comandos
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            waybar_init
            ;;
        "validate")
            waybar_validate
            ;;
        "start")
            waybar_start
            ;;
        "stop")
            waybar_stop
            ;;
        "restart")
            waybar_restart
            ;;
        "reload")
            waybar_reload
            ;;
        "apply_theme")
            waybar_apply_theme "$2"
            ;;
        "set_layout")
            waybar_set_layout "$2"
            ;;
        "cleanup")
            waybar_cleanup
            ;;
        "health_check")
            waybar_health_check
            ;;
        "status")
            waybar_get_status
            ;;
        "help"|"-h"|"--help")
            echo "Waybar Component Commands:"
            echo "  init                  - Inicializar componente"
            echo "  validate              - Validar configuração"
            echo "  start                 - Iniciar Waybar"
            echo "  stop                  - Parar Waybar"
            echo "  restart               - Reiniciar Waybar"
            echo "  reload                - Recarregar configuração"
            echo "  apply_theme <nome>    - Aplicar tema"
            echo "  set_layout <nome>     - Definir layout"
            echo "  cleanup               - Limpeza do componente"
            echo "  health_check          - Verificar saúde"
            echo "  status                - Mostrar status detalhado"
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