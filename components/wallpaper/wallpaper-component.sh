#!/bin/bash

# Wallpaper Component - Gerenciamento de papéis de parede (Versão Funcional)
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do componente
COMPONENT_DIR="$(dirname "${BASH_SOURCE[0]}")"
CONFIG_FILE="$COMPONENT_DIR/wallpaper-config.conf"
WALLPAPER_DIR="$HOME/Imagens/wallpapers"
CURRENT_WALLPAPER=""
IS_INITIALIZED=false

# Inicializar componente
wallpaper_init() {
    log_info "[WallpaperComponent] Inicializando componente Wallpaper..."
    
    # Criar estrutura necessária
    wallpaper_create_structure
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "wallpaper.set" "wallpaper_handle_set"
    fi
    
    IS_INITIALIZED=true
    log_info "[WallpaperComponent] Wallpaper inicializado"
    return 0
}

# Criar estrutura necessária
wallpaper_create_structure() {
    # Criar diretório de wallpapers se não existir
    mkdir -p "$WALLPAPER_DIR"
    
    # Criar arquivo de configuração se não existir
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# Wallpaper Component Configuration
WALLPAPER_DIR=$WALLPAPER_DIR
CURRENT_WALLPAPER=
AUTO_CHANGE=false
CHANGE_INTERVAL=3600
EOF
        log_info "[WallpaperComponent] Arquivo de configuração criado"
    fi
}

# Validar configuração
wallpaper_validate() {
    log_info "[WallpaperComponent] Validando configuração..."
    
    if [ ! -d "$WALLPAPER_DIR" ]; then
        log_error "[WallpaperComponent] Diretório de wallpapers não encontrado: $WALLPAPER_DIR"
        return 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "[WallpaperComponent] Arquivo de configuração não encontrado: $CONFIG_FILE"
        return 1
    fi
    
    return 0
}

# Listar wallpapers disponíveis
wallpaper_list() {
    log_info "[WallpaperComponent] Listando wallpapers disponíveis..."
    
    if [ ! -d "$WALLPAPER_DIR" ]; then
        log_error "[WallpaperComponent] Diretório não encontrado: $WALLPAPER_DIR"
        return 1
    fi
    
    echo "Wallpapers disponíveis em $WALLPAPER_DIR:"
    find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | while read -r wallpaper; do
        local basename_file="$(basename "$wallpaper")"
        local filesize="$(du -h "$wallpaper" 2>/dev/null | cut -f1)"
        echo "  📷 $basename_file ($filesize)"
    done
    
    return 0
}

# Definir wallpaper
wallpaper_set() {
    local wallpaper_path="$1"
    
    if [ -z "$wallpaper_path" ]; then
        log_error "[WallpaperComponent] Caminho do wallpaper não informado"
        return 1
    fi
    
    # Verificar se arquivo existe
    if [ ! -f "$wallpaper_path" ]; then
        # Tentar encontrar no diretório padrão
        local alt_path="$WALLPAPER_DIR/$wallpaper_path"
        if [ -f "$alt_path" ]; then
            wallpaper_path="$alt_path"
        else
            log_error "[WallpaperComponent] Wallpaper não encontrado: $wallpaper_path"
            return 1
        fi
    fi
    
    log_info "[WallpaperComponent] Definindo wallpaper: $wallpaper_path"
    
    # Aplicar wallpaper usando diferentes métodos
    wallpaper_apply_with_hyprpaper "$wallpaper_path" || \
    wallpaper_apply_with_sway "$wallpaper_path" || \
    wallpaper_apply_with_feh "$wallpaper_path" || {
        log_error "[WallpaperComponent] Falha ao aplicar wallpaper"
        return 1
    }
    
    # Salvar wallpaper atual
    CURRENT_WALLPAPER="$wallpaper_path"
    sed -i "s|CURRENT_WALLPAPER=.*|CURRENT_WALLPAPER=$wallpaper_path|" "$CONFIG_FILE" 2>/dev/null
    
    # Emitir evento de mudança
    if command -v emit_event >/dev/null 2>&1; then
        emit_event "wallpaper.changed" "{\"path\": \"$wallpaper_path\", \"timestamp\": \"$(date)\"}"
    fi
    
    log_info "[WallpaperComponent] Wallpaper aplicado com sucesso"
    return 0
}

# Aplicar wallpaper com hyprpaper
wallpaper_apply_with_hyprpaper() {
    local wallpaper_path="$1"
    
    if ! command -v hyprpaper >/dev/null 2>&1; then
        return 1
    fi
    
    log_info "[WallpaperComponent] Aplicando com hyprpaper"
    
    # Criar configuração temporária para hyprpaper
    local hyprpaper_conf="/tmp/hyprpaper_$(date +%s).conf"
    cat > "$hyprpaper_conf" << EOF
preload = $wallpaper_path
wallpaper = ,$wallpaper_path
EOF
    
    # Parar hyprpaper atual
    pkill hyprpaper 2>/dev/null || true
    sleep 1
    
    # Iniciar com nova configuração
    hyprpaper -c "$hyprpaper_conf" &
    
    # Limpar arquivo temporário após um tempo
    sleep 3 && rm -f "$hyprpaper_conf" &
    
    return 0
}

# Aplicar wallpaper com sway
wallpaper_apply_with_sway() {
    local wallpaper_path="$1"
    
    if ! command -v swaymsg >/dev/null 2>&1; then
        return 1
    fi
    
    log_info "[WallpaperComponent] Aplicando com sway"
    swaymsg output "*" bg "$wallpaper_path" fill 2>/dev/null
    
    return $?
}

# Aplicar wallpaper com feh (fallback)
wallpaper_apply_with_feh() {
    local wallpaper_path="$1"
    
    if ! command -v feh >/dev/null 2>&1; then
        return 1
    fi
    
    log_info "[WallpaperComponent] Aplicando com feh"
    feh --bg-fill "$wallpaper_path" 2>/dev/null
    
    return $?
}

# Wallpaper aleatório
wallpaper_random() {
    log_info "[WallpaperComponent] Selecionando wallpaper aleatório..."
    
    # Buscar wallpapers disponíveis
    local wallpapers_array=()
    while IFS= read -r -d '' wallpaper; do
        wallpapers_array+=("$wallpaper")
    done < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
    
    if [ ${#wallpapers_array[@]} -eq 0 ]; then
        log_error "[WallpaperComponent] Nenhum wallpaper encontrado"
        return 1
    fi
    
    # Selecionar aleatoriamente
    local random_index=$((RANDOM % ${#wallpapers_array[@]}))
    local selected_wallpaper="${wallpapers_array[$random_index]}"
    
    log_info "[WallpaperComponent] Wallpaper selecionado: $(basename "$selected_wallpaper")"
    wallpaper_set "$selected_wallpaper"
}

# Aplicar tema (para compatibilidade)
wallpaper_apply_theme() {
    local theme_name="${1:-default}"
    log_info "[WallpaperComponent] Tema aplicado: $theme_name (sem ação específica)"
    return 0
}

# Recarregar configuração
wallpaper_reload() {
    log_info "[WallpaperComponent] Recarregando configuração..."
    
    # Re-ler configuração
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    
    # Reaplicar wallpaper atual se definido
    if [ -n "$CURRENT_WALLPAPER" ] && [ -f "$CURRENT_WALLPAPER" ]; then
        wallpaper_set "$CURRENT_WALLPAPER"
    fi
    
    return 0
}

# Limpeza do componente
wallpaper_cleanup() {
    log_info "[WallpaperComponent] Limpeza do Wallpaper..."
    
    # Parar processos relacionados se necessário
    pkill hyprpaper 2>/dev/null || true
    
    return 0
}

# Verificação de saúde
wallpaper_health_check() {
    local health_issues=0
    
    # Verificar diretório de wallpapers
    if [ ! -d "$WALLPAPER_DIR" ]; then
        ((health_issues++))
    fi
    
    # Verificar se tem pelo menos um wallpaper
    if ! find "$WALLPAPER_DIR" -name "*.jpg" -o -name "*.png" -o -name "*.webp" | head -1 | grep -q . 2>/dev/null; then
        ((health_issues++))
    fi
    
    # Verificar se algum aplicador está disponível
    if ! command -v hyprpaper >/dev/null 2>&1 && \
       ! command -v swaymsg >/dev/null 2>&1 && \
       ! command -v feh >/dev/null 2>&1; then
        ((health_issues++))
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return 0
}

# Handler para definir wallpaper
wallpaper_handle_set() {
    local event_data="$1"
    log_info "[WallpaperComponent] Evento de definição de wallpaper: $event_data"
    
    # Extrair path do evento
    local wallpaper_path
    wallpaper_path="$(echo "$event_data" | grep -o '"path":"[^"]*"' | cut -d'"' -f4)"
    
    if [ -n "$wallpaper_path" ]; then
        wallpaper_set "$wallpaper_path"
    fi
}

# Obter status do componente
wallpaper_get_status() {
    echo "=================================="
    echo "   WALLPAPER COMPONENT STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Configuração:"
    echo "  - Diretório: $WALLPAPER_DIR"
    echo "  - Wallpaper atual: ${CURRENT_WALLPAPER:-"nenhum"}"
    echo "  - Inicializado: $IS_INITIALIZED"
    echo ""
    
    echo "📁 Wallpapers:"
    if [ -d "$WALLPAPER_DIR" ]; then
        local count="$(find "$WALLPAPER_DIR" -name "*.jpg" -o -name "*.png" -o -name "*.webp" 2>/dev/null | wc -l)"
        echo "  📷 $count wallpapers encontrados"
    else
        echo "  ❌ Diretório não encontrado"
    fi
    
    echo ""
    echo "🔧 Aplicadores:"
    if command -v hyprpaper >/dev/null 2>&1; then
        echo "  ✅ hyprpaper"
    else
        echo "  ❌ hyprpaper"
    fi
    
    if command -v swaymsg >/dev/null 2>&1; then
        echo "  ✅ sway"
    else
        echo "  ❌ sway"
    fi
    
    if command -v feh >/dev/null 2>&1; then
        echo "  ✅ feh"
    else
        echo "  ❌ feh"
    fi
    
    echo ""
}

# Função principal para roteamento de comandos
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            wallpaper_init
            ;;
        "validate")
            wallpaper_validate
            ;;
        "list")
            wallpaper_list
            ;;
        "set")
            wallpaper_set "$2"
            ;;
        "random")
            wallpaper_random
            ;;
        "apply_theme")
            wallpaper_apply_theme "$2"
            ;;
        "reload")
            wallpaper_reload
            ;;
        "cleanup")
            wallpaper_cleanup
            ;;
        "health_check")
            wallpaper_health_check
            ;;
        "status")
            wallpaper_get_status
            ;;
        "help"|"-h"|"--help")
            echo "Wallpaper Component Commands:"
            echo "  init                  - Inicializar componente"
            echo "  validate              - Validar configuração"
            echo "  list                  - Listar wallpapers disponíveis"
            echo "  set <arquivo>         - Definir wallpaper"
            echo "  random                - Wallpaper aleatório"
            echo "  apply_theme <nome>    - Aplicar tema (compatibilidade)"
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