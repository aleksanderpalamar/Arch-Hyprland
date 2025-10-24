#!/bin/bash

# Theme Engine - Sistema centralizado de gerenciamento de temas
# Gerencia temas para todos os componentes do sistema

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do Theme Engine
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$PROJECT_ROOT/themes"
CURRENT_THEME_FILE="$PROJECT_ROOT/config/current-theme.conf"
THEME_CACHE_DIR="$PROJECT_ROOT/cache/themes"

# Registry de componentes
declare -A registered_components
declare -A theme_variants
declare -A theme_metadata

# Estado do engine
current_theme=""
is_initialized=false

# Inicializar Theme Engine
theme_engine_init() {
    log_info "[ThemeEngine] Inicializando Theme Engine..."
    
    # Criar estruturas necessárias
    theme_engine_create_structure
    
    # Descobrir temas disponíveis
    theme_engine_discover_themes
    
    # Carregar tema atual
    theme_engine_load_current_theme
    
    # Registrar handlers de eventos
    if command -v register_event_handler >/dev/null 2>&1; then
        register_event_handler "wallpaper.changed" "theme_engine_handle_wallpaper_change"
        register_event_handler "component.registered" "theme_engine_handle_component_registration"
    fi
    
    is_initialized=true
    log_info "[ThemeEngine] Theme Engine inicializado"
    return 0
}

# Criar estrutura de temas
theme_engine_create_structure() {
    mkdir -p "$THEMES_DIR"/{default,dark,light,custom}
    mkdir -p "$THEME_CACHE_DIR"
    mkdir -p "$(dirname "$CURRENT_THEME_FILE")"
    
    # Criar tema padrão se não existir
    if [ ! -f "$THEMES_DIR/default/theme.conf" ]; then
        theme_engine_create_default_theme
    fi
    
    # Criar arquivo de tema atual se não existir
    if [ ! -f "$CURRENT_THEME_FILE" ]; then
        echo "CURRENT_THEME=default" > "$CURRENT_THEME_FILE"
        echo "THEME_VARIANT=standard" >> "$CURRENT_THEME_FILE"
        echo "LAST_UPDATED=$(date)" >> "$CURRENT_THEME_FILE"
    fi
}

# Criar tema padrão
theme_engine_create_default_theme() {
    local default_theme="$THEMES_DIR/default"
    mkdir -p "$default_theme"
    
    # Configuração do tema
    cat > "$default_theme/theme.conf" << 'EOF'
# Default Theme Configuration
THEME_NAME="Default"
THEME_VERSION="1.0.0"
THEME_AUTHOR="System"
THEME_DESCRIPTION="Tema padrão do sistema"

# Color Palette
PRIMARY_COLOR="#5e81ac"
SECONDARY_COLOR="#81a1c1"
ACCENT_COLOR="#88c0d0"
BACKGROUND_COLOR="#2e3440"
SURFACE_COLOR="#3b4252"
TEXT_COLOR="#eceff4"
TEXT_SECONDARY="#d8dee9"
ERROR_COLOR="#bf616a"
WARNING_COLOR="#ebcb8b"
SUCCESS_COLOR="#a3be8c"

# Variants
VARIANTS="standard,compact,minimal"
DEFAULT_VARIANT="standard"

# Component Support
SUPPORTS_WAYBAR=true
SUPPORTS_ROFI=true
SUPPORTS_HYPRLAND=true
SUPPORTS_WALLPAPER=true
EOF

    # Template para Waybar
    mkdir -p "$default_theme/waybar"
    cat > "$default_theme/waybar/style.css" << 'EOF'
/* Default Theme - Waybar */
* {
    font-family: "JetBrains Mono Nerd Font";
    font-size: 12px;
    min-height: 0;
}

window#waybar {
    background: rgba(46, 52, 64, 0.9);
    color: #eceff4;
    border-radius: 8px;
    margin: 5px;
}

.module {
    padding: 0 10px;
    margin: 2px;
    border-radius: 4px;
}

#workspaces button {
    padding: 0 8px;
    background: rgba(59, 66, 82, 0.8);
    color: #d8dee9;
    border-radius: 4px;
    margin: 2px;
}

#workspaces button.active {
    background: #5e81ac;
    color: #eceff4;
}

#clock, #battery, #network, #pulseaudio {
    background: rgba(59, 66, 82, 0.6);
    padding: 0 12px;
    margin: 2px;
    border-radius: 4px;
}
EOF

    # Template para Rofi
    mkdir -p "$default_theme/rofi"
    cat > "$default_theme/rofi/theme.rasi" << 'EOF'
/* Default Theme - Rofi */
* {
    bg: #2e3440;
    fg: #eceff4;
    accent: #5e81ac;
    surface: #3b4252;
    
    background-color: transparent;
    text-color: @fg;
}

window {
    background-color: @bg;
    border-radius: 8px;
    padding: 20px;
    width: 600px;
}

inputbar {
    background-color: @surface;
    border-radius: 4px;
    padding: 8px 12px;
}

listview {
    lines: 8;
    margin: 10px 0 0 0;
}

element {
    padding: 8px 12px;
    border-radius: 4px;
}

element selected {
    background-color: @accent;
}
EOF

    log_info "[ThemeEngine] Tema padrão criado"
}

# Descobrir temas disponíveis
theme_engine_discover_themes() {
    log_info "[ThemeEngine] Descobrindo temas disponíveis..."
    
    for theme_dir in "$THEMES_DIR"/*; do
        if [ -d "$theme_dir" ] && [ -f "$theme_dir/theme.conf" ]; then
            local theme_name="$(basename "$theme_dir")"
            
            # Carregar metadados do tema
            theme_engine_load_theme_metadata "$theme_name"
            
            log_info "[ThemeEngine] Tema descoberto: $theme_name"
        fi
    done
}

# Carregar metadados do tema
theme_engine_load_theme_metadata() {
    local theme_name="$1"
    local theme_conf="$THEMES_DIR/$theme_name/theme.conf"
    
    if [ -f "$theme_conf" ]; then
        # Extrair informações básicas
        local theme_version="$(grep "^THEME_VERSION=" "$theme_conf" | cut -d'=' -f2 | tr -d '"')"
        local theme_author="$(grep "^THEME_AUTHOR=" "$theme_conf" | cut -d'=' -f2 | tr -d '"')"
        local variants="$(grep "^VARIANTS=" "$theme_conf" | cut -d'=' -f2 | tr -d '"')"
        
        # Armazenar metadados
        theme_metadata["$theme_name.version"]="$theme_version"
        theme_metadata["$theme_name.author"]="$theme_author"
        theme_variants["$theme_name"]="$variants"
    fi
}

# Carregar tema atual
theme_engine_load_current_theme() {
    if [ -f "$CURRENT_THEME_FILE" ]; then
        source "$CURRENT_THEME_FILE" 2>/dev/null || {
            log_warn "[ThemeEngine] Erro ao carregar tema atual, usando padrão"
            current_theme="default"
            return 1
        }
        current_theme="$CURRENT_THEME"
    else
        current_theme="default"
    fi
    
    log_info "[ThemeEngine] Tema atual: $current_theme"
}

# Registrar componente no engine
theme_engine_register_component() {
    local component_name="$1"
    local component_script="$2"
    
    if [ -z "$component_name" ] || [ -z "$component_script" ]; then
        log_error "[ThemeEngine] Parâmetros inválidos para registro de componente"
        return 1
    fi
    
    registered_components["$component_name"]="$component_script"
    log_info "[ThemeEngine] Componente registrado: $component_name"
    
    # Aplicar tema atual ao novo componente
    if [ -n "$current_theme" ]; then
        theme_engine_apply_to_component "$component_name" "$current_theme"
    fi
    
    return 0
}

# Listar temas disponíveis
theme_engine_list_themes() {
    echo "=================================="
    echo "    TEMAS DISPONÍVEIS"
    echo "=================================="
    echo ""
    
    for theme_dir in "$THEMES_DIR"/*; do
        if [ -d "$theme_dir" ] && [ -f "$theme_dir/theme.conf" ]; then
            local theme_name="$(basename "$theme_dir")"
            local version="${theme_metadata["$theme_name.version"]:-"desconhecida"}"
            local author="${theme_metadata["$theme_name.author"]:-"desconhecido"}"
            local variants="${theme_variants["$theme_name"]:-"standard"}"
            
            echo "🎨 $theme_name"
            echo "   📦 Versão: $version"
            echo "   👤 Autor: $author"
            echo "   🔧 Variantes: $variants"
            
            if [ "$theme_name" = "$current_theme" ]; then
                echo "   ✅ ATIVO"
            fi
            
            echo ""
        fi
    done
}

# Aplicar tema
theme_engine_apply_theme() {
    local theme_name="${1:-$current_theme}"
    local variant="${2:-standard}"
    
    if [ -z "$theme_name" ]; then
        log_error "[ThemeEngine] Nome do tema não especificado"
        return 1
    fi
    
    local theme_dir="$THEMES_DIR/$theme_name"
    if [ ! -d "$theme_dir" ]; then
        log_error "[ThemeEngine] Tema não encontrado: $theme_name"
        return 1
    fi
    
    log_info "[ThemeEngine] Aplicando tema: $theme_name (variante: $variant)"
    
    # Aplicar tema a todos os componentes registrados
    for component_name in "${!registered_components[@]}"; do
        theme_engine_apply_to_component "$component_name" "$theme_name" "$variant"
    done
    
    # Salvar tema atual
    theme_engine_save_current_theme "$theme_name" "$variant"
    
    # Emitir evento de mudança de tema
    if command -v emit_event >/dev/null 2>&1; then
        emit_event "theme.changed" "{\"theme\": \"$theme_name\", \"variant\": \"$variant\", \"timestamp\": \"$(date)\"}"
    fi
    
    current_theme="$theme_name"
    log_info "[ThemeEngine] Tema aplicado com sucesso"
    return 0
}

# Aplicar tema a componente específico
theme_engine_apply_to_component() {
    local component_name="$1"
    local theme_name="$2"
    local variant="${3:-standard}"
    
    local component_script="${registered_components[$component_name]}"
    if [ -z "$component_script" ]; then
        log_warn "[ThemeEngine] Componente não registrado: $component_name"
        return 1
    fi
    
    local theme_dir="$THEMES_DIR/$theme_name"
    if [ ! -d "$theme_dir" ]; then
        log_error "[ThemeEngine] Tema não encontrado: $theme_name"
        return 1
    fi
    
    log_info "[ThemeEngine] Aplicando tema $theme_name ao componente $component_name"
    
    # Verificar se componente suporta aplicação de tema
    if [ -x "$component_script" ]; then
        # Tentar aplicar tema via script do componente
        bash "$component_script" apply_theme "$theme_name" "$variant" 2>/dev/null || {
            log_warn "[ThemeEngine] Componente $component_name não suporta apply_theme"
        }
    fi
    
    # Aplicar arquivos específicos do tema para o componente
    theme_engine_copy_component_theme_files "$component_name" "$theme_name" "$variant"
    
    return 0
}

# Copiar arquivos de tema para componente
theme_engine_copy_component_theme_files() {
    local component_name="$1"
    local theme_name="$2"
    local variant="$3"
    
    local theme_component_dir="$THEMES_DIR/$theme_name/$component_name"
    local target_component_dir="$PROJECT_ROOT/components/$component_name"
    
    if [ ! -d "$theme_component_dir" ]; then
        log_info "[ThemeEngine] Sem arquivos específicos de tema para $component_name"
        return 0
    fi
    
    if [ ! -d "$target_component_dir" ]; then
        log_warn "[ThemeEngine] Diretório do componente não encontrado: $target_component_dir"
        return 1
    fi
    
    # Copiar arquivos de tema
    find "$theme_component_dir" -type f | while read -r theme_file; do
        local relative_path="${theme_file#$theme_component_dir/}"
        local target_file="$target_component_dir/$relative_path"
        
        # Criar diretório se necessário
        mkdir -p "$(dirname "$target_file")"
        
        # Copiar arquivo
        cp "$theme_file" "$target_file" && {
            log_info "[ThemeEngine] Copiado: $relative_path para $component_name"
        }
    done
}

# Salvar tema atual
theme_engine_save_current_theme() {
    local theme_name="$1"
    local variant="$2"
    
    cat > "$CURRENT_THEME_FILE" << EOF
CURRENT_THEME=$theme_name
THEME_VARIANT=$variant
LAST_UPDATED=$(date)
EOF
}

# Status do Theme Engine
theme_engine_status() {
    echo "=================================="
    echo "     THEME ENGINE STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Engine:"
    echo "  - Status: $([ "$is_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "  - Tema atual: $current_theme"
    echo "  - Diretório de temas: $THEMES_DIR"
    echo ""
    
    echo "🎨 Temas:"
    local theme_count="$(find "$THEMES_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l)"
    ((theme_count--)) # Remover o diretório pai da contagem
    echo "  - Total disponível: $theme_count"
    
    echo ""
    echo "🔗 Componentes registrados:"
    if [ ${#registered_components[@]} -eq 0 ]; then
        echo "  - Nenhum componente registrado"
    else
        for component in "${!registered_components[@]}"; do
            echo "  - $component: ${registered_components[$component]}"
        done
    fi
    
    echo ""
}

# Health check
theme_engine_health_check() {
    local health_issues=0
    
    # Verificar estrutura
    if [ ! -d "$THEMES_DIR" ]; then
        ((health_issues++))
    fi
    
    if [ ! -f "$CURRENT_THEME_FILE" ]; then
        ((health_issues++))
    fi
    
    # Verificar tema atual
    if [ -n "$current_theme" ]; then
        local theme_dir="$THEMES_DIR/$current_theme"
        if [ ! -d "$theme_dir" ] || [ ! -f "$theme_dir/theme.conf" ]; then
            ((health_issues++))
        fi
    else
        ((health_issues++))
    fi
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $health_issues
}

# Handler para mudança de wallpaper
theme_engine_handle_wallpaper_change() {
    local event_data="$1"
    log_info "[ThemeEngine] Wallpaper alterado, recalculando cores do tema"
    
    # Se usando wallust, regenerar tema baseado nas novas cores
    if command -v wallust >/dev/null 2>&1; then
        theme_engine_generate_wallust_theme
    fi
}

# Gerar tema baseado no wallust
theme_engine_generate_wallust_theme() {
    log_info "[ThemeEngine] Gerando tema baseado em cores do wallust..."
    
    local wallust_theme_dir="$THEMES_DIR/wallust-auto"
    mkdir -p "$wallust_theme_dir"
    
    # Gerar configuração automática (placeholder)
    cat > "$wallust_theme_dir/theme.conf" << 'EOF'
# Auto-generated Wallust Theme
THEME_NAME="Wallust Auto"
THEME_VERSION="auto"
THEME_AUTHOR="Wallust"
THEME_DESCRIPTION="Tema gerado automaticamente baseado no wallpaper"

# Colors from wallust (placeholders)
PRIMARY_COLOR="{{primary}}"
SECONDARY_COLOR="{{secondary}}"
BACKGROUND_COLOR="{{background}}"
TEXT_COLOR="{{foreground}}"

VARIANTS="standard"
DEFAULT_VARIANT="standard"

SUPPORTS_WAYBAR=true
SUPPORTS_ROFI=true
SUPPORTS_HYPRLAND=true
EOF
}

# Handler para registro de componente
theme_engine_handle_component_registration() {
    local event_data="$1"
    log_info "[ThemeEngine] Novo componente registrado: $event_data"
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            theme_engine_init
            ;;
        "list")
            theme_engine_list_themes
            ;;
        "apply")
            theme_engine_apply_theme "$2" "$3"
            ;;
        "register")
            theme_engine_register_component "$2" "$3"
            ;;
        "status")
            theme_engine_status
            ;;
        "health_check")
            theme_engine_health_check
            ;;
        "current")
            echo "Tema atual: $current_theme"
            ;;
        "help"|"-h"|"--help")
            echo "Theme Engine Commands:"
            echo "  init                        - Inicializar engine"
            echo "  list                        - Listar temas disponíveis"
            echo "  apply <tema> [variante]     - Aplicar tema"
            echo "  register <nome> <script>    - Registrar componente"
            echo "  status                      - Status do engine"
            echo "  health_check                - Verificar saúde"
            echo "  current                     - Mostrar tema atual"
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