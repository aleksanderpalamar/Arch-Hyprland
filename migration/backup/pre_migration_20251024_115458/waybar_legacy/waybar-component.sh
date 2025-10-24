#!/bin/bash

# Waybar Component - Gerenciamento modular da barra de status
# Implementa a interface Component e integra com o sistema de eventos

source "$(dirname "${BASH_SOURCE[0]}")/../interface.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh"

class WaybarComponent implements Component {
    private config_path="$HOME/.config/waybar"
    private current_layout="default"
    private current_theme="default"
    private modules=()
    private is_initialized=false
    
    # Implementação da interface Component
    public init() {
        log_info "Initializing Waybar component..."
        
        create_config_structure
        load_default_layout
        register_modules
        setup_event_listeners
        
        is_initialized=true
        log_info "Waybar component initialized successfully"
        return 0
    }
    
    public validate() {
        local errors=0
        
        # Validar estrutura de diretórios
        if [[ ! -d "$config_path" ]]; then
            log_error "Waybar config directory not found: $config_path"
            ((errors++))
        fi
        
        # Validar arquivo de configuração principal
        if [[ -f "$config_path/config.jsonc" ]]; then
            if ! python3 -c "import json; json.load(open('$config_path/config.jsonc'))" 2>/dev/null; then
                log_error "Invalid JSON in waybar config.jsonc"
                ((errors++))
            fi
        else
            log_error "Waybar config.jsonc not found"
            ((errors++))
        fi
        
        # Validar CSS
        if [[ ! -f "$config_path/style.css" ]]; then
            log_error "Waybar style.css not found"
            ((errors++))
        fi
        
        return $errors
    }
    
    public apply_theme() {
        local theme_name="$1"
        
        if [[ -z "$theme_name" ]]; then
            log_error "Theme name is required"
            return 1
        fi
        
        log_info "Applying theme '$theme_name' to Waybar..."
        
        # Gerar CSS do tema
        if generate_css_from_theme "$theme_name"; then
            current_theme="$theme_name"
            reload_waybar
            
            # Emitir evento de mudança de tema
            EventSystem::emit "waybar_theme_changed" "$theme_name"
            
            log_info "Theme '$theme_name' applied successfully"
            return 0
        else
            log_error "Failed to apply theme '$theme_name'"
            return 1
        fi
    }
    
    public cleanup() {
        log_info "Cleaning up Waybar component..."
        
        # Parar waybar se estiver rodando
        if pgrep waybar >/dev/null; then
            pkill waybar
            log_info "Waybar process terminated"
        fi
        
        # Limpar arquivos temporários
        find "$config_path" -name "*.tmp" -delete 2>/dev/null
        
        is_initialized=false
        return 0
    }
    
    public health_check() {
        local health_score=100
        local issues=()
        
        # Verificar se o waybar está rodando
        if ! pgrep waybar >/dev/null; then
            issues+=("Waybar process not running")
            ((health_score -= 30))
        fi
        
        # Verificar uso de memória
        if pgrep waybar >/dev/null; then
            local mem_usage=$(ps -p "$(pgrep waybar)" -o rss= 2>/dev/null | awk '{print $1}')
            if [[ $mem_usage -gt 102400 ]]; then  # > 100MB
                issues+=("High memory usage: ${mem_usage}KB")
                ((health_score -= 20))
            fi
        fi
        
        # Verificar arquivos de configuração
        if ! validate >/dev/null 2>&1; then
            issues+=("Configuration validation failed")
            ((health_score -= 25))
        fi
        
        # Retornar resultado da verificação
        if [[ $health_score -ge 80 ]]; then
            log_info "Waybar health check: GOOD (score: $health_score)"
        elif [[ $health_score -ge 60 ]]; then
            log_warn "Waybar health check: WARNING (score: $health_score)"
        else
            log_error "Waybar health check: CRITICAL (score: $health_score)"
        fi
        
        if [[ ${#issues[@]} -gt 0 ]]; then
            log_warn "Health check issues found:"
            printf '%s\n' "${issues[@]}" | while read -r issue; do
                log_warn "  - $issue"
            done
        fi
        
        return $((100 - health_score))
    }
    
    # Métodos específicos do Waybar
    public load_layout() {
        local layout_name="$1"
        local layout_file="$config_path/layouts/$layout_name.jsonc"
        
        if [[ ! -f "$layout_file" ]]; then
            log_error "Layout file not found: $layout_file"
            return 1
        fi
        
        log_info "Loading layout: $layout_name"
        
        # Fazer backup da configuração atual
        cp "$config_path/config.jsonc" "$config_path/config.jsonc.backup"
        
        # Copiar novo layout
        if cp "$layout_file" "$config_path/config.jsonc"; then
            current_layout="$layout_name"
            reload_waybar
            
            EventSystem::emit "waybar_layout_changed" "$layout_name"
            log_info "Layout '$layout_name' loaded successfully"
            return 0
        else
            log_error "Failed to load layout '$layout_name'"
            return 1
        fi
    }
    
    public add_module() {
        local module_name="$1"
        
        if [[ -z "$module_name" ]]; then
            log_error "Module name is required"
            return 1
        fi
        
        # Verificar se módulo já existe
        if [[ " ${modules[*]} " =~ " $module_name " ]]; then
            log_warn "Module '$module_name' already added"
            return 0
        fi
        
        log_info "Adding module: $module_name"
        modules+=("$module_name")
        
        # Regenerar configuração com novo módulo
        regenerate_config
        
        EventSystem::emit "waybar_module_added" "$module_name"
        return 0
    }
    
    public get_status() {
        local status="unknown"
        local pid=""
        
        if pgrep waybar >/dev/null; then
            status="running"
            pid=$(pgrep waybar)
        else
            status="stopped"
        fi
        
        echo "{"
        echo "  \"status\": \"$status\","
        echo "  \"pid\": \"$pid\","
        echo "  \"layout\": \"$current_layout\","
        echo "  \"theme\": \"$current_theme\","
        echo "  \"modules\": [\"$(IFS=','; echo "${modules[*]}")\"],"
        echo "  \"initialized\": $is_initialized"
        echo "}"
    }
    
    # Métodos privados
    private create_config_structure() {
        log_info "Creating Waybar config structure..."
        
        mkdir -p "$config_path"/{layouts,themes,modules,cache}
        
        # Criar layout padrão se não existir
        if [[ ! -f "$config_path/layouts/default.jsonc" ]]; then
            create_default_layout
        fi
        
        # Criar tema padrão se não existir
        if [[ ! -f "$config_path/themes/default.css" ]]; then
            create_default_theme
        fi
        
        # Criar módulos básicos se não existirem
        create_basic_modules
    }
    
    private create_default_layout() {
        cat > "$config_path/layouts/default.jsonc" << 'EOF'
{
    "layer": "top",
    "mode": "dock",
    "exclusive": true,
    "passthrough": false,
    "position": "top",
    "spacing": 3,
    "fixed-center": true,
    "ipc": true,
    "margin-top": 3,
    "margin-left": 8,
    "margin-right": 8,
    "modules-left": [
        "hyprland/workspaces",
        "custom/separator"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "tray",
        "network",
        "bluetooth", 
        "pulseaudio",
        "cpu",
        "memory",
        "custom/power"
    ]
}
EOF
    }
    
    private create_default_theme() {
        cat > "$config_path/themes/default.css" << 'EOF'
/* Waybar Default Theme */
* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.8);
    color: #ffffff;
    border-radius: 10px;
}

#workspaces button {
    padding: 0 8px;
    margin: 0 2px;
    border-radius: 4px;
    color: #ffffff;
    background-color: transparent;
}

#workspaces button.active {
    background-color: #8257e6;
}

#clock {
    color: #ffffff;
    font-weight: bold;
}
EOF
    }
    
    private create_basic_modules() {
        # Criar módulos básicos se não existirem
        mkdir -p "$config_path/modules"
    }
    
    private load_default_layout() {
        if [[ -f "$config_path/layouts/default.jsonc" ]]; then
            cp "$config_path/layouts/default.jsonc" "$config_path/config.jsonc"
            current_layout="default"
        fi
    }
    
    private register_modules() {
        # Registrar módulos padrão
        modules=(
            "workspaces"
            "system" 
            "status"
        )
    }
    
    private setup_event_listeners() {
        # Registrar listeners para eventos relevantes
        EventSystem::subscribe "theme_changed" "WaybarComponent::handle_theme_change"
        EventSystem::subscribe "wallpaper_changed" "WaybarComponent::handle_wallpaper_change"
    }
    
    private generate_css_from_theme() {
        local theme_name="$1"
        local theme_file="$config_path/themes/$theme_name.css"
        local output_file="$config_path/style.css"
        
        if [[ ! -f "$theme_file" ]]; then
            # Use default theme if requested theme doesn't exist
            theme_file="$config_path/themes/default.css"
        fi
        
        if [[ -f "$theme_file" ]]; then
            # Copiar tema para arquivo ativo
            cp "$theme_file" "$output_file"
            return 0
        else
            log_error "No theme file found"
            return 1
        fi
    }
    
    private reload_waybar() {
        log_info "Reloading Waybar..."
        
        if pgrep waybar >/dev/null; then
            pkill waybar
            sleep 0.5
        fi
        
        # Iniciar waybar em background
        waybar &
        
        # Aguardar inicialização
        local timeout=10
        while ! pgrep waybar >/dev/null && ((timeout-- > 0)); do
            sleep 0.5
        done
        
        if pgrep waybar >/dev/null; then
            log_info "Waybar reloaded successfully"
            EventSystem::emit "waybar_reloaded" "$current_layout"
        else
            log_error "Failed to reload Waybar"
            return 1
        fi
    }
    
    private regenerate_config() {
        # Regenerar configuração baseada nos módulos ativos
        log_info "Regenerating Waybar configuration..."
        reload_waybar
    }
    
    # Event handlers
    public handle_theme_change() {
        local theme_data="$1"
        log_info "Handling theme change: $theme_data"
        apply_theme "$theme_data"
    }
    
    public handle_wallpaper_change() {
        local wallpaper_data="$1"
        log_info "Handling wallpaper change: $wallpaper_data"
        
        # Regenerar cores se wallust estiver disponível
        if command -v wallust >/dev/null; then
            sleep 1  # Aguardar wallust processar
            apply_theme "$current_theme"
        fi
    }
}

# Funções de logging
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [WaybarComponent] $*"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [WaybarComponent] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [WaybarComponent] $*"
}