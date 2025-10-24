#!/bin/bash

# Rofi Component - Gerenciamento do menu de aplicações (Versão Funcional)
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do componente
COMPONENT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CONFIG_PATH="$HOME/.config/rofi"
CURRENT_THEME="default"
IS_INITIALIZED=false

# Inicializar componente
rofi_init() {
    log_info "[RofiComponent] Inicializando componente Rofi..."
    
    rofi_create_config_structure
    rofi_validate_config
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "theme.changed" "rofi_handle_theme_change"
        register_event_handler "wallpaper.changed" "rofi_handle_wallpaper_change"
    fi
    
    IS_INITIALIZED=true
    log_info "[RofiComponent] Rofi inicializado"
    return 0
}

# Criar estrutura de configuração
rofi_create_config_structure() {
    log_info "[RofiComponent] Criando estrutura de configuração..."
    
    # Criar diretório se não existir
    mkdir -p "$CONFIG_PATH"
    
    # Copiar configurações se não existirem
    if [ ! -f "$CONFIG_PATH/config.rasi" ] && [ -f "$COMPONENT_DIR/config.rasi" ]; then
        log_info "[RofiComponent] Copiando configuração padrão"
        cp "$COMPONENT_DIR/config.rasi" "$CONFIG_PATH/config.rasi"
    fi
    
    if [ ! -f "$CONFIG_PATH/theme.rasi" ] && [ -f "$COMPONENT_DIR/theme.rasi" ]; then
        log_info "[RofiComponent] Copiando tema padrão"
        cp "$COMPONENT_DIR/theme.rasi" "$CONFIG_PATH/theme.rasi"
    fi
    
    # Copiar estrutura wallust se existir
    if [ -d "$COMPONENT_DIR/wallust" ] && [ ! -d "$CONFIG_PATH/wallust" ]; then
        log_info "[RofiComponent] Copiando configurações wallust"
        cp -r "$COMPONENT_DIR/wallust" "$CONFIG_PATH/"
    fi
}

# Validar configuração
rofi_validate() {
    log_info "[RofiComponent] Validando configuração..."
    
    local required_files=("config.rasi" "theme.rasi")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$COMPONENT_DIR/$file" ]; then
            log_error "[RofiComponent] Arquivo obrigatório não encontrado: $file"
            return 1
        fi
    done
    
    return 0
}

# Verificar se configuração é válida
rofi_validate_config() {
    log_info "[RofiComponent] Validando configuração do Rofi..."
    
    if [ ! -f "$COMPONENT_DIR/config.rasi" ]; then
        log_error "[RofiComponent] config.rasi não encontrado"
        return 1
    fi
    
    if [ ! -f "$COMPONENT_DIR/theme.rasi" ]; then
        log_error "[RofiComponent] theme.rasi não encontrado"
        return 1
    fi
    
    # Testar sintaxe do rofi (se rofi estiver instalado)
    if command -v rofi >/dev/null 2>&1; then
        if ! rofi -config "$COMPONENT_DIR/config.rasi" -help >/dev/null 2>&1; then
            log_warn "[RofiComponent] Configuração pode ter erros de sintaxe"
        fi
    fi
    
    log_info "[RofiComponent] Configuração válida"
    return 0
}

# Executar Rofi
rofi_run() {
    local mode="${1:-drun}"
    log_info "[RofiComponent] Executando Rofi no modo: $mode"
    
    if ! command -v rofi >/dev/null 2>&1; then
        log_error "[RofiComponent] Rofi não está instalado"
        return 1
    fi
    
    # Executar rofi com configuração do componente
    rofi -show "$mode" \
         -config "$COMPONENT_DIR/config.rasi" \
         -theme "$COMPONENT_DIR/theme.rasi" &
    
    return 0
}

# Mostrar aplicações
rofi_show_applications() {
    log_info "[RofiComponent] Mostrando menu de aplicações"
    rofi_run "drun"
}

# Mostrar janelas
rofi_show_windows() {
    log_info "[RofiComponent] Mostrando seletor de janelas"
    rofi_run "window"
}

# Mostrar executáveis
rofi_show_run() {
    log_info "[RofiComponent] Mostrando executor de comandos"
    rofi_run "run"
}

# Aplicar tema
rofi_apply_theme() {
    local theme_name="${1:-default}"
    log_info "[RofiComponent] Aplicando tema: $theme_name"
    
    CURRENT_THEME="$theme_name"
    
    # Verificar se tema existe
    local theme_file="$COMPONENT_DIR/themes/$theme_name.rasi"
    if [ -f "$theme_file" ]; then
        log_info "[RofiComponent] Usando tema personalizado: $theme_file"
        # Aqui poderia copiar ou linkar o tema específico
    else
        log_info "[RofiComponent] Usando tema padrão"
    fi
    
    return 0
}

# Recarregar configuração
rofi_reload() {
    log_info "[RofiComponent] Recarregando configuração Rofi..."
    
    # Rofi não tem processo persistente, apenas validar configs
    rofi_validate_config
    
    return 0
}

# Limpeza do componente
rofi_cleanup() {
    log_info "[RofiComponent] Limpeza do Rofi concluída"
    # Rofi não tem processo persistente, nada para limpar
    return 0
}

# Verificação de saúde
rofi_health_check() {
    local health_issues=0
    
    # Verificar arquivos de configuração
    if [ ! -f "$COMPONENT_DIR/config.rasi" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$COMPONENT_DIR/theme.rasi" ]; then
        ((health_issues++))
    fi
    
    # Verificar se rofi está instalado
    if ! command -v rofi >/dev/null 2>&1; then
        ((health_issues++))
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return 0
}

# Handler para mudança de tema
rofi_handle_theme_change() {
    local event_data="$1"
    log_info "[RofiComponent] Tema alterado: $event_data"
    
    # Extrair nome do tema do evento
    local theme_name
    theme_name="$(echo "$event_data" | grep -o '"theme":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$theme_name" ]; then
        rofi_apply_theme "$theme_name"
    fi
}

# Handler para mudança de wallpaper
rofi_handle_wallpaper_change() {
    local event_data="$1"
    log_info "[RofiComponent] Wallpaper alterado: $event_data"
    
    # Se usando wallust, as cores podem ter mudado
    if [ -d "$COMPONENT_DIR/wallust" ]; then
        log_info "[RofiComponent] Cores wallust podem ter sido atualizadas"
    fi
}

# Obter status do componente
rofi_get_status() {
    echo "=================================="
    echo "     ROFI COMPONENT STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Configuração:"
    echo "  - Diretório: $COMPONENT_DIR"
    echo "  - Tema atual: $CURRENT_THEME"
    echo "  - Inicializado: $IS_INITIALIZED"
    echo ""
    
    echo "📁 Arquivos:"
    if [ -f "$COMPONENT_DIR/config.rasi" ]; then
        echo "  ✅ config.rasi"
    else
        echo "  ❌ config.rasi"
    fi
    
    if [ -f "$COMPONENT_DIR/theme.rasi" ]; then
        echo "  ✅ theme.rasi"
    else
        echo "  ❌ theme.rasi"
    fi
    
    if [ -f "$COMPONENT_DIR/shared-fonts.rasi" ]; then
        echo "  ✅ shared-fonts.rasi"
    else
        echo "  ⚠️  shared-fonts.rasi (opcional)"
    fi
    
    if [ -d "$COMPONENT_DIR/wallust" ]; then
        echo "  ✅ wallust/ ($(ls -1 "$COMPONENT_DIR/wallust" | wc -l) arquivos)"
    else
        echo "  ⚠️  wallust/ (opcional)"
    fi
    
    echo ""
    echo "🔧 Sistema:"
    if command -v rofi >/dev/null 2>&1; then
        local rofi_version="$(rofi -version 2>/dev/null | head -1 || echo "desconhecida")"
        echo "  ✅ Rofi instalado ($rofi_version)"
    else
        echo "  ❌ Rofi não instalado"
    fi
    
    echo ""
}

# Função principal para roteamento de comandos
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            rofi_init
            ;;
        "validate")
            rofi_validate
            ;;
        "run")
            rofi_run "$2"
            ;;
        "applications"|"apps")
            rofi_show_applications
            ;;
        "windows")
            rofi_show_windows
            ;;
        "commands")
            rofi_show_run
            ;;
        "apply_theme")
            rofi_apply_theme "$2"
            ;;
        "reload")
            rofi_reload
            ;;
        "cleanup")
            rofi_cleanup
            ;;
        "health_check")
            rofi_health_check
            ;;
        "status")
            rofi_get_status
            ;;
        "help"|"-h"|"--help")
            echo "Rofi Component Commands:"
            echo "  init                  - Inicializar componente"
            echo "  validate              - Validar configuração"
            echo "  run <modo>            - Executar Rofi (drun/window/run)"
            echo "  applications          - Mostrar menu de aplicações"
            echo "  windows               - Mostrar seletor de janelas"
            echo "  commands              - Mostrar executor de comandos"
            echo "  apply_theme <nome>    - Aplicar tema"
            echo "  reload                - Recarregar configuração"
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