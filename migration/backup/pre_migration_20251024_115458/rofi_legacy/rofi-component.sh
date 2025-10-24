#!/bin/bash

# Rofi Component - Gerenciamento do lançador de aplicativos
# Implementa a interface Component e integra com sistema de themes

source "$(dirname "${BASH_SOURCE[0]}")/../interface.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh"

class RofiComponent implements Component {
    private config_path="$HOME/.config/rofi"
    private current_theme="default"
    private current_mode="drun"
    private is_initialized=false
    
    # Implementação da interface Component
    public init() {
        log_info "Initializing Rofi component..."
        
        create_config_structure
        setup_default_config
        setup_themes
        setup_event_listeners
        
        is_initialized=true
        log_info "Rofi component initialized successfully"
        return 0
    }
    
    public validate() {
        local errors=0
        
        # Verificar se rofi está instalado
        if ! command -v rofi >/dev/null; then
            log_error "rofi command not found"
            ((errors++))
        fi
        
        # Validar estrutura de diretórios
        if [[ ! -d "$config_path" ]]; then
            log_error "Rofi config directory not found: $config_path"
            ((errors++))
        fi
        
        # Validar arquivo de configuração principal
        if [[ -f "$config_path/config.rasi" ]]; then
            if ! rofi -dump-config -config "$config_path/config.rasi" >/dev/null 2>&1; then
                log_error "Invalid rofi configuration in config.rasi"
                ((errors++))
            fi
        else
            log_warn "Rofi config.rasi not found, will be created"
        fi
        
        # Validar tema atual
        if [[ -f "$config_path/themes/$current_theme.rasi" ]]; then
            if ! validate_rasi_syntax "$config_path/themes/$current_theme.rasi"; then
                log_error "Invalid RASI syntax in theme: $current_theme"
                ((errors++))
            fi
        fi
        
        return $errors
    }
    
    public apply_theme() {
        local theme_name="$1"
        
        if [[ -z "$theme_name" ]]; then
            log_error "Theme name is required"
            return 1
        fi
        
        log_info "Applying theme '$theme_name' to Rofi..."
        
        # Verificar se tema existe
        local theme_file="$config_path/themes/$theme_name.rasi"
        if [[ ! -f "$theme_file" ]]; then
            log_error "Theme file not found: $theme_file"
            return 1
        fi
        
        # Aplicar tema
        if apply_rofi_theme "$theme_name"; then
            current_theme="$theme_name"
            
            # Emitir evento de mudança de tema
            EventSystem::emit "rofi_theme_changed" "$theme_name"
            
            log_info "Theme '$theme_name' applied successfully"
            return 0
        else
            log_error "Failed to apply theme '$theme_name'"
            return 1
        fi
    }
    
    public cleanup() {
        log_info "Cleaning up Rofi component..."
        
        # Matar processos rofi se estiverem rodando
        pkill rofi 2>/dev/null || true
        
        # Limpar arquivos temporários
        find "$config_path" -name "*.tmp" -delete 2>/dev/null
        
        is_initialized=false
        return 0
    }
    
    public health_check() {
        local health_score=100
        local issues=()
        
        # Verificar se rofi está disponível
        if ! command -v rofi >/dev/null; then
            issues+=("rofi command not available")
            ((health_score -= 50))
        fi
        
        # Verificar configuração
        if ! validate >/dev/null 2>&1; then
            issues+=("Configuration validation failed")
            ((health_score -= 25))
        fi
        
        # Verificar tema atual
        if [[ ! -f "$config_path/themes/$current_theme.rasi" ]]; then
            issues+=("Current theme file missing: $current_theme.rasi")
            ((health_score -= 20))
        fi
        
        # Verificar wallust integration
        if [[ -d "$config_path/wallust" ]]; then
            if [[ ! -f "$config_path/wallust/colors-rofi.rasi" ]]; then
                issues+=("wallust colors not available")
                ((health_score -= 10))
            fi
        fi
        
        # Retornar resultado da verificação
        if [[ $health_score -ge 80 ]]; then
            log_info "Rofi health check: GOOD (score: $health_score)"
        elif [[ $health_score -ge 60 ]]; then
            log_warn "Rofi health check: WARNING (score: $health_score)"
        else
            log_error "Rofi health check: CRITICAL (score: $health_score)"
        fi
        
        if [[ ${#issues[@]} -gt 0 ]]; then
            log_warn "Health check issues found:"
            printf '%s\n' "${issues[@]}" | while read -r issue; do
                log_warn "  - $issue"
            done
        fi
        
        return $((100 - health_score))
    }
    
    # Métodos específicos do Rofi
    public launch() {
        local mode="${1:-$current_mode}"
        local extra_args="${2:-}"
        
        log_info "Launching Rofi in mode: $mode"
        
        # Matar instância anterior se existir
        pkill rofi 2>/dev/null || true
        
        # Construir comando rofi
        local rofi_cmd="rofi -show $mode -config $config_path/config.rasi"
        
        if [[ -n "$extra_args" ]]; then
            rofi_cmd="$rofi_cmd $extra_args"
        fi
        
        # Executar rofi
        eval "$rofi_cmd" &
        
        return 0
    }
    
    public set_mode() {
        local new_mode="$1"
        
        case "$new_mode" in
            "drun"|"run"|"window"|"ssh"|"combi"|"keys"|"filebrowser")
                current_mode="$new_mode"
                log_info "Rofi mode set to: $new_mode"
                return 0
                ;;
            *)
                log_error "Invalid rofi mode: $new_mode"
                return 1
                ;;
        esac
    }
    
    public get_available_themes() {
        if [[ -d "$config_path/themes" ]]; then
            find "$config_path/themes" -name "*.rasi" -exec basename {} .rasi \;
        fi
    }
    
    public get_status() {
        local rofi_running=false
        if pgrep rofi >/dev/null; then
            rofi_running=true
        fi
        
        echo "{"
        echo "  \"current_theme\": \"$current_theme\","
        echo "  \"current_mode\": \"$current_mode\","
        echo "  \"config_path\": \"$config_path\","
        echo "  \"rofi_running\": $rofi_running,"
        echo "  \"initialized\": $is_initialized"
        echo "}"
    }
    
    # Métodos privados
    private create_config_structure() {
        log_info "Creating Rofi config structure..."
        
        mkdir -p "$config_path"/{themes,modes,wallust}
        
        # Mover arquivos existentes se necessário
        local component_dir="$(dirname "${BASH_SOURCE[0]}")"
        if [[ -f "$component_dir/config.rasi" ]]; then
            cp "$component_dir/config.rasi" "$config_path/"
        fi
        
        if [[ -f "$component_dir/shared-fonts.rasi" ]]; then
            cp "$component_dir/shared-fonts.rasi" "$config_path/"
        fi
        
        if [[ -f "$component_dir/theme.rasi" ]]; then
            cp "$component_dir/theme.rasi" "$config_path/themes/default.rasi"
        fi
        
        if [[ -d "$component_dir/wallust" ]]; then
            cp -r "$component_dir/wallust"/* "$config_path/wallust/"
        fi
    }
    
    private setup_default_config() {
        local config_file="$config_path/config.rasi"
        
        if [[ ! -f "$config_file" ]]; then
            cat > "$config_file" << 'EOF'
// Rofi Configuration - Generated by RofiComponent
@import "~/.config/rofi/shared-fonts.rasi"
@theme "~/.config/rofi/themes/default.rasi"

configuration {
    modi: "drun,run,filebrowser,window";
    show-icons: true;
    display-drun: "  Apps";
    display-run: "  Run";
    display-filebrowser: "  Files";
    display-window: "  Windows";
    drun-display-format: "{name}";
    window-format: "{w} · {c} · {t}";
    hover-select: true;
    me-select-entry: "MouseSecondary";
    me-accept-entry: "MousePrimary";
    terminal: "kitty";
    ssh-client: "ssh";
    ssh-command: "{terminal} -e {ssh-client} {host}";
}
EOF
        fi
    }
    
    private setup_themes() {
        # Criar tema padrão se não existir
        if [[ ! -f "$config_path/themes/default.rasi" ]]; then
            create_default_theme
        fi
        
        # Criar tema escuro
        if [[ ! -f "$config_path/themes/dark.rasi" ]]; then
            create_dark_theme
        fi
        
        # Criar tema claro
        if [[ ! -f "$config_path/themes/light.rasi" ]]; then
            create_light_theme
        fi
    }
    
    private create_default_theme() {
        cat > "$config_path/themes/default.rasi" << 'EOF'
/* Default Rofi Theme - Generated by RofiComponent */

/* Load wallust colors if available */
@import "~/.config/rofi/wallust/colors-rofi.rasi"

* {
    border-color: #8257e6;
    handle-color: #8257e6;
    background-color: rgba(30, 30, 46, 0.9);
    foreground-color: #ffffff;
    normal-background: rgba(30, 30, 46, 0.9);
    normal-foreground: #ffffff;
    selected-normal-background: #8257e6;
    selected-normal-foreground: #ffffff;
    alternate-normal-background: rgba(30, 30, 46, 0.9);
    alternate-normal-foreground: #ffffff;
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: false;
    width: 35%;
    x-offset: 0px;
    y-offset: 0px;
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 2px solid;
    border-radius: 10px;
    border-color: @border-color;
    cursor: "default";
    background-color: @background-color;
}

mainbox {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 20px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border-color;
    background-color: inherit;
    children: [ "inputbar", "listview" ];
}

inputbar {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 8px 12px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border-color;
    background-color: rgba(255, 255, 255, 0.1);
    text-color: @foreground-color;
    children: [ "prompt", "entry" ];
}

prompt {
    enabled: true;
    background-color: inherit;
    text-color: inherit;
}

entry {
    enabled: true;
    background-color: inherit;
    text-color: inherit;
    cursor: text;
    placeholder: "Search...";
    placeholder-color: inherit;
}

listview {
    enabled: true;
    columns: 1;
    lines: 8;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 5px;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border-color;
    background-color: transparent;
    text-color: @foreground-color;
    cursor: "default";
}

element {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 6px;
    border-color: @border-color;
    background-color: transparent;
    text-color: @foreground-color;
    cursor: pointer;
}

element selected {
    background-color: @selected-normal-background;
    text-color: @selected-normal-foreground;
}

element-icon {
    background-color: transparent;
    text-color: inherit;
    size: 24px;
    cursor: inherit;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: inherit;
    cursor: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
}
EOF
    }
    
    private create_dark_theme() {
        cat > "$config_path/themes/dark.rasi" << 'EOF'
/* Dark Rofi Theme */
@import "~/.config/rofi/wallust/colors-rofi.rasi"

* {
    border-color: #444444;
    background-color: rgba(20, 20, 20, 0.95);
    foreground-color: #ffffff;
    selected-normal-background: #333333;
    selected-normal-foreground: #ffffff;
}

/* Inherit structure from default theme */
@import "~/.config/rofi/themes/default.rasi"
EOF
    }
    
    private create_light_theme() {
        cat > "$config_path/themes/light.rasi" << 'EOF'
/* Light Rofi Theme */
* {
    border-color: #cccccc;
    background-color: rgba(240, 240, 240, 0.95);
    foreground-color: #333333;
    selected-normal-background: #0078d4;
    selected-normal-foreground: #ffffff;
}

/* Inherit structure from default theme */
@import "~/.config/rofi/themes/default.rasi"
EOF
    }
    
    private setup_event_listeners() {
        # Registrar listeners para eventos relevantes
        EventSystem::subscribe "theme_changed" "RofiComponent::handle_theme_change"
        EventSystem::subscribe "wallpaper_changed" "RofiComponent::handle_wallpaper_change"
    }
    
    private validate_rasi_syntax() {
        local rasi_file="$1"
        
        # Validação básica de sintaxe RASI
        if [[ ! -f "$rasi_file" ]]; then
            return 1
        fi
        
        # Verificar se rofi consegue processar o arquivo
        if rofi -dump-theme -theme "$rasi_file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    }
    
    private apply_rofi_theme() {
        local theme_name="$1"
        local theme_file="$config_path/themes/$theme_name.rasi"
        
        # Atualizar configuração para usar o novo tema
        sed -i "s|@theme \".*\"|@theme \"$theme_file\"|" "$config_path/config.rasi"
        
        log_info "Rofi theme configuration updated"
        return 0
    }
    
    # Event handlers
    public handle_theme_change() {
        local theme_data="$1"
        log_info "Handling theme change: $theme_data"
        
        # Aplicar tema correspondente
        case "$theme_data" in
            *"dark"*)
                apply_theme "dark"
                ;;
            *"light"*)
                apply_theme "light"
                ;;
            *)
                apply_theme "default"
                ;;
        esac
    }
    
    public handle_wallpaper_change() {
        local wallpaper_data="$1"
        log_info "Handling wallpaper change: $wallpaper_data"
        
        # Se wallust estiver disponível, aguardar atualização das cores
        if command -v wallust >/dev/null; then
            sleep 1  # Aguardar wallust processar
            
            # Verificar se cores foram atualizadas
            if [[ -f "$config_path/wallust/colors-rofi.rasi" ]]; then
                log_info "Rofi colors updated from wallust"
            fi
        fi
    }
}

# Funções de logging
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [RofiComponent] $*"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [RofiComponent] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [RofiComponent] $*"
}