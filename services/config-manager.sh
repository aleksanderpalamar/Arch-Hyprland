#!/bin/bash

# Configuration Manager - Gerencia configurações de forma modular
# Centraliza o acesso e validação de todas as configurações do sistema

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../components/interface.sh"

class ConfigManager {
    private -A config_registry=()
    private -A validation_rules=()
    private -A component_configs=()
    private -A config_templates=()
    private config_root="$HOME/.config"
    private backup_dir="$config_root/hypr-backup"
    private log_level="INFO"
    private initialized=false
    
    # Interface Implementation
    public init() {
        log_info "[ConfigManager] Inicializando Configuration Manager..."
        
        # Criar diretório de backup
        mkdir -p "$backup_dir"
        
        # Registrar eventos do sistema
        register_event_handler "config.changed" "_handle_config_change"
        register_event_handler "component.registered" "_handle_component_registration"
        register_event_handler "theme.changed" "_handle_theme_change"
        
        # Carregar configurações base
        _load_base_configs
        _load_component_configs
        
        initialized=true
        emit_event "config.manager.initialized" "{\"status\": \"ready\"}"
        log_info "[ConfigManager] Configuration Manager inicializado com sucesso"
        return 0
    }
    
    public validate() {
        if [ "$initialized" != "true" ]; then
            log_error "[ConfigManager] Tentativa de validar manager não inicializado"
            return 1
        fi
        
        log_info "[ConfigManager] Validando todas as configurações..."
        local errors=0
        
        for config_name in "${!config_registry[@]}"; do
            if ! validate_config "$config_name"; then
                ((errors++))
            fi
        done
        
        if [ $errors -gt 0 ]; then
            log_error "[ConfigManager] $errors configurações falharam na validação"
            return 1
        fi
        
        log_info "[ConfigManager] Todas as configurações validadas com sucesso"
        return 0
    }
    
    public apply_theme() {
        local theme_name="$1"
        
        if [ -z "$theme_name" ]; then
            log_error "[ConfigManager] Nome do tema não fornecido"
            return 1
        fi
        
        log_info "[ConfigManager] Aplicando tema: $theme_name"
        
        # Notificar componentes sobre mudança de tema
        emit_event "theme.applying" "{\"theme\": \"$theme_name\"}"
        
        # Aplicar tema em configurações específicas
        _apply_theme_to_configs "$theme_name"
        
        # Recarregar configurações afetadas
        _reload_affected_configs "$theme_name"
        
        emit_event "theme.applied" "{\"theme\": \"$theme_name\"}"
        log_info "[ConfigManager] Tema $theme_name aplicado com sucesso"
        return 0
    }
    
    public cleanup() {
        log_info "[ConfigManager] Executando limpeza do Configuration Manager..."
        
        # Salvar estado atual
        _save_manager_state
        
        # Limpar registros temporários
        config_registry=()
        validation_rules=()
        component_configs=()
        
        initialized=false
        emit_event "config.manager.cleanup" "{\"status\": \"completed\"}"
        log_info "[ConfigManager] Limpeza concluída"
        return 0
    }
    
    public health_check() {
        local status="healthy"
        local issues=()
        
        # Verificar inicialização
        if [ "$initialized" != "true" ]; then
            status="unhealthy"
            issues+=("Manager não inicializado")
        fi
        
        # Verificar integridade dos arquivos de configuração
        for config_name in "${!config_registry[@]}"; do
            local config_path="${config_registry[$config_name]}"
            if [ ! -f "$config_path" ] && [ ! -d "$config_path" ]; then
                status="degraded"
                issues+=("Configuração $config_name não encontrada: $config_path")
            fi
        done
        
        # Verificar diretório de backup
        if [ ! -d "$backup_dir" ]; then
            status="degraded"
            issues+=("Diretório de backup não existe")
        fi
        
        # Log do status
        case "$status" in
            "healthy")
                log_info "[ConfigManager] Health check: Sistema saudável"
                ;;
            "degraded")
                log_warn "[ConfigManager] Health check: Sistema degradado - ${issues[*]}"
                ;;
            "unhealthy")
                log_error "[ConfigManager] Health check: Sistema não saudável - ${issues[*]}"
                ;;
        esac
        
        echo "$status"
        return $([ "$status" = "healthy" ] && echo 0 || echo 1)
    }
    
    # Métodos Públicos do Configuration Manager
    public register_config() {
        local config_name="$1"
        local config_path="$2"
        local validator="$3"
        local component="$4"
        
        if [ -z "$config_name" ] || [ -z "$config_path" ]; then
            log_error "[ConfigManager] Parâmetros obrigatórios faltando para registro"
            return 1
        fi
        
        config_registry["$config_name"]="$config_path"
        if [ -n "$validator" ]; then
            validation_rules["$config_name"]="$validator"
        fi
        
        if [ -n "$component" ]; then
            component_configs["$config_name"]="$component"
        fi
        
        log_info "[ConfigManager] Configuração registrada: $config_name -> $config_path"
        emit_event "config.registered" "{\"name\": \"$config_name\", \"path\": \"$config_path\"}"
        return 0
    }
    
    public unregister_config() {
        local config_name="$1"
        
        if [ -z "$config_name" ]; then
            log_error "[ConfigManager] Nome da configuração não fornecido"
            return 1
        fi
        
        unset config_registry["$config_name"]
        unset validation_rules["$config_name"]
        unset component_configs["$config_name"]
        
        log_info "[ConfigManager] Configuração removida: $config_name"
        emit_event "config.unregistered" "{\"name\": \"$config_name\"}"
        return 0
    }
    
    public get_config() {
        local config_name="$1"
        
        if [ -z "$config_name" ]; then
            log_error "[ConfigManager] Nome da configuração não fornecido"
            return 1
        fi
        
        if [ -n "${config_registry[$config_name]}" ]; then
            echo "${config_registry[$config_name]}"
            return 0
        fi
        
        log_warn "[ConfigManager] Configuração não encontrada: $config_name"
        return 1
    }
    
    public list_configs() {
        for config_name in "${!config_registry[@]}"; do
            local config_path="${config_registry[$config_name]}"
            local component="${component_configs[$config_name]:-"N/A"}"
            echo "$config_name:$config_path:$component"
        done
    }
    
    public validate_config() {
        local config_name="$1"
        
        if [ -z "$config_name" ]; then
            log_error "[ConfigManager] Nome da configuração não fornecido"
            return 1
        fi
        
        local config_path="${config_registry[$config_name]}"
        if [ -z "$config_path" ]; then
            log_error "[ConfigManager] Configuração não registrada: $config_name"
            return 1
        fi
        
        # Verificar se o arquivo/diretório existe
        if [ ! -f "$config_path" ] && [ ! -d "$config_path" ]; then
            log_error "[ConfigManager] Arquivo/diretório não encontrado: $config_path"
            return 1
        fi
        
        # Executar validação customizada se disponível
        local validator="${validation_rules[$config_name]}"
        if [ -n "$validator" ] && command -v "$validator" >/dev/null 2>&1; then
            if ! "$validator" "$config_path"; then
                log_error "[ConfigManager] Validação falhou para $config_name"
                return 1
            fi
        fi
        
        log_debug "[ConfigManager] Configuração $config_name validada com sucesso"
        return 0
    }
    
    public backup_config() {
        local config_name="$1"
        local timestamp="$(date +%Y%m%d_%H%M%S)"
        
        if [ -z "$config_name" ]; then
            # Backup de todas as configurações
            log_info "[ConfigManager] Iniciando backup completo..."
            
            local backup_full_dir="$backup_dir/full_backup_$timestamp"
            mkdir -p "$backup_full_dir"
            
            for cfg in "${!config_registry[@]}"; do
                _backup_single_config "$cfg" "$backup_full_dir"
            done
            
            log_info "[ConfigManager] Backup completo salvo em: $backup_full_dir"
        else
            # Backup de configuração específica
            local config_path="${config_registry[$config_name]}"
            if [ -z "$config_path" ]; then
                log_error "[ConfigManager] Configuração não encontrada: $config_name"
                return 1
            fi
            
            local backup_single_dir="$backup_dir/${config_name}_$timestamp"
            mkdir -p "$backup_single_dir"
            _backup_single_config "$config_name" "$backup_single_dir"
            
            log_info "[ConfigManager] Backup de $config_name salvo em: $backup_single_dir"
        fi
        
        return 0
    }
    
    public restore_config() {
        local config_name="$1"
        local backup_path="$2"
        
        if [ -z "$config_name" ] || [ -z "$backup_path" ]; then
            log_error "[ConfigManager] Parâmetros de restauração incompletos"
            return 1
        fi
        
        if [ ! -d "$backup_path" ]; then
            log_error "[ConfigManager] Diretório de backup não encontrado: $backup_path"
            return 1
        fi
        
        local config_path="${config_registry[$config_name]}"
        if [ -z "$config_path" ]; then
            log_error "[ConfigManager] Configuração não registrada: $config_name"
            return 1
        fi
        
        log_info "[ConfigManager] Restaurando $config_name de $backup_path..."
        
        # Fazer backup do estado atual antes de restaurar
        backup_config "$config_name"
        
        # Restaurar configuração
        if [ -f "$backup_path/$config_name" ]; then
            cp "$backup_path/$config_name" "$config_path"
        elif [ -d "$backup_path/$config_name" ]; then
            rm -rf "$config_path"
            cp -r "$backup_path/$config_name" "$config_path"
        else
            log_error "[ConfigManager] Arquivo de backup não encontrado"
            return 1
        fi
        
        # Validar configuração restaurada
        if ! validate_config "$config_name"; then
            log_error "[ConfigManager] Configuração restaurada é inválida"
            return 1
        fi
        
        emit_event "config.restored" "{\"name\": \"$config_name\", \"backup\": \"$backup_path\"}"
        log_info "[ConfigManager] Configuração $config_name restaurada com sucesso"
        return 0
    }
    
    public reload_config() {
        local config_name="$1"
        
        if [ -z "$config_name" ]; then
            log_error "[ConfigManager] Nome da configuração não fornecido"
            return 1
        fi
        
        # Validar antes de recarregar
        if ! validate_config "$config_name"; then
            log_error "[ConfigManager] Configuração inválida, cancelando reload"
            return 1
        fi
        
        # Notificar componente associado
        local component="${component_configs[$config_name]}"
        if [ -n "$component" ]; then
            emit_event "config.reload" "{\"name\": \"$config_name\", \"component\": \"$component\"}"
        fi
        
        log_info "[ConfigManager] Configuração $config_name recarregada"
        return 0
    }
    
    public create_template() {
        local template_name="$1"
        local source_config="$2"
        
        if [ -z "$template_name" ] || [ -z "$source_config" ]; then
            log_error "[ConfigManager] Parâmetros do template incompletos"
            return 1
        fi
        
        local source_path="${config_registry[$source_config]}"
        if [ -z "$source_path" ] || [ ! -f "$source_path" ]; then
            log_error "[ConfigManager] Configuração source não encontrada"
            return 1
        fi
        
        local template_dir="$config_root/templates"
        mkdir -p "$template_dir"
        
        local template_path="$template_dir/${template_name}.template"
        cp "$source_path" "$template_path"
        
        config_templates["$template_name"]="$template_path"
        
        log_info "[ConfigManager] Template $template_name criado: $template_path"
        return 0
    }
    
    public apply_template() {
        local template_name="$1"
        local target_config="$2"
        
        if [ -z "$template_name" ] || [ -z "$target_config" ]; then
            log_error "[ConfigManager] Parâmetros do template incompletos"
            return 1
        fi
        
        local template_path="${config_templates[$template_name]}"
        if [ -z "$template_path" ] || [ ! -f "$template_path" ]; then
            log_error "[ConfigManager] Template não encontrado: $template_name"
            return 1
        fi
        
        local target_path="${config_registry[$target_config]}"
        if [ -z "$target_path" ]; then
            log_error "[ConfigManager] Configuração alvo não registrada: $target_config"
            return 1
        fi
        
        # Backup antes de aplicar template
        backup_config "$target_config"
        
        # Aplicar template
        cp "$template_path" "$target_path"
        
        # Validar resultado
        if ! validate_config "$target_config"; then
            log_error "[ConfigManager] Template resultou em configuração inválida"
            return 1
        fi
        
        emit_event "template.applied" "{\"template\": \"$template_name\", \"target\": \"$target_config\"}"
        log_info "[ConfigManager] Template $template_name aplicado a $target_config"
        return 0
    }
    
    # Métodos Privados
    private _load_base_configs() {
        local hypr_dir="$config_root/hypr"
        
        if [ -d "$hypr_dir" ]; then
            register_config "hyprland" "$hypr_dir/hyprland.conf" "_validate_hyprland_config" "hyprland"
            register_config "hyprpaper" "$hypr_dir/hyprpaper.conf" "_validate_hyprpaper_config" "wallpaper"
            register_config "monitors" "$hypr_dir/monitors.conf" "_validate_config_file" "hyprland"
            register_config "workspaces" "$hypr_dir/workspaces.conf" "_validate_config_file" "hyprland"
        fi
        
        if [ -d "$config_root/waybar" ]; then
            register_config "waybar" "$config_root/waybar/config.jsonc" "_validate_json_config" "waybar"
            register_config "waybar_style" "$config_root/waybar/style.css" "_validate_config_file" "waybar"
        fi
        
        if [ -d "$config_root/rofi" ]; then
            register_config "rofi" "$config_root/rofi/config.rasi" "_validate_rasi_config" "rofi"
        fi
        
        log_info "[ConfigManager] Configurações base carregadas"
    }
    
    private _load_component_configs() {
        local components_dir="$(dirname "${BASH_SOURCE[0]}")/../components"
        
        for component_dir in "$components_dir"/*; do
            if [ -d "$component_dir" ]; then
                local component_name="$(basename "$component_dir")"
                local config_file="$component_dir/config.conf"
                
                if [ -f "$config_file" ]; then
                    register_config "component_$component_name" "$config_file" "_validate_component_config" "$component_name"
                fi
            fi
        done
        
        log_info "[ConfigManager] Configurações de componentes carregadas"
    }
    
    private _handle_config_change() {
        local event_data="$1"
        local config_name="$(echo "$event_data" | grep -o '"name": "[^"]*"' | cut -d'"' -f4)"
        
        if [ -n "$config_name" ]; then
            log_info "[ConfigManager] Processando mudança na configuração: $config_name"
            reload_config "$config_name"
        fi
    }
    
    private _handle_component_registration() {
        local event_data="$1"
        local component_name="$(echo "$event_data" | grep -o '"component": "[^"]*"' | cut -d'"' -f4)"
        
        if [ -n "$component_name" ]; then
            log_info "[ConfigManager] Novo componente registrado: $component_name"
            _load_component_configs
        fi
    }
    
    private _handle_theme_change() {
        local event_data="$1"
        local theme_name="$(echo "$event_data" | grep -o '"theme": "[^"]*"' | cut -d'"' -f4)"
        
        if [ -n "$theme_name" ]; then
            log_info "[ConfigManager] Processando mudança de tema: $theme_name"
            apply_theme "$theme_name"
        fi
    }
    
    private _apply_theme_to_configs() {
        local theme_name="$1"
        
        # Aplicar tema específico para cada tipo de configuração
        for config_name in "${!config_registry[@]}"; do
            local component="${component_configs[$config_name]}"
            case "$component" in
                "waybar")
                    _apply_waybar_theme "$config_name" "$theme_name"
                    ;;
                "rofi")
                    _apply_rofi_theme "$config_name" "$theme_name"
                    ;;
                "wallpaper")
                    _apply_wallpaper_theme "$config_name" "$theme_name"
                    ;;
            esac
        done
    }
    
    private _reload_affected_configs() {
        local theme_name="$1"
        
        # Recarregar configurações que são afetadas por mudanças de tema
        for config_name in "${!config_registry[@]}"; do
            local component="${component_configs[$config_name]}"
            if [[ "$component" =~ ^(waybar|rofi|wallpaper)$ ]]; then
                reload_config "$config_name"
            fi
        done
    }
    
    private _backup_single_config() {
        local config_name="$1"
        local backup_dir="$2"
        local config_path="${config_registry[$config_name]}"
        
        if [ -f "$config_path" ]; then
            cp "$config_path" "$backup_dir/"
        elif [ -d "$config_path" ]; then
            cp -r "$config_path" "$backup_dir/"
        fi
        
        log_debug "[ConfigManager] Backup de $config_name concluído"
    }
    
    private _save_manager_state() {
        local state_file="$backup_dir/manager_state.conf"
        
        echo "# Configuration Manager State - $(date)" > "$state_file"
        echo "initialized=$initialized" >> "$state_file"
        echo "config_count=${#config_registry[@]}" >> "$state_file"
        
        for config_name in "${!config_registry[@]}"; do
            echo "config[$config_name]=${config_registry[$config_name]}" >> "$state_file"
        done
        
        log_debug "[ConfigManager] Estado do manager salvo"
    }
    
    # Validadores específicos
    private _validate_hyprland_config() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Verificações básicas de sintaxe Hyprland
        if ! grep -q "^source\|^bind\|^exec" "$config_path"; then
            log_warn "[ConfigManager] Configuração Hyprland pode estar incompleta"
        fi
        
        return 0
    }
    
    private _validate_hyprpaper_config() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Verificar se tem pelo menos uma configuração de wallpaper
        if ! grep -q "^wallpaper\|^preload" "$config_path"; then
            log_warn "[ConfigManager] Configuração hyprpaper sem wallpapers definidos"
        fi
        
        return 0
    }
    
    private _validate_json_config() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Validar JSON (se python estiver disponível)
        if command -v python3 >/dev/null 2>&1; then
            if ! python3 -c "import json; json.load(open('$config_path'))" 2>/dev/null; then
                log_error "[ConfigManager] JSON inválido: $config_path"
                return 1
            fi
        fi
        
        return 0
    }
    
    private _validate_rasi_config() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Verificações básicas RASI
        if ! grep -q "@import\|configuration\|{" "$config_path"; then
            log_warn "[ConfigManager] Configuração RASI pode estar incompleta"
        fi
        
        return 0
    }
    
    private _validate_config_file() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Validação genérica - apenas verificar se o arquivo existe e é legível
        if [ ! -r "$config_path" ]; then
            log_error "[ConfigManager] Arquivo não é legível: $config_path"
            return 1
        fi
        
        return 0
    }
    
    private _validate_component_config() {
        local config_path="$1"
        
        if [ ! -f "$config_path" ]; then
            return 1
        fi
        
        # Validar estrutura básica de configuração de componente
        local required_fields=("component_name" "component_version" "enabled")
        
        for field in "${required_fields[@]}"; do
            if ! grep -q "^$field=" "$config_path"; then
                log_warn "[ConfigManager] Campo obrigatório $field não encontrado em $config_path"
                return 1
            fi
        done
        
        return 0
    }
    
    private _apply_waybar_theme() {
        local config_name="$1"
        local theme_name="$2"
        
        log_debug "[ConfigManager] Aplicando tema Waybar: $theme_name"
        # Implementar lógica específica do Waybar
    }
    
    private _apply_rofi_theme() {
        local config_name="$1"
        local theme_name="$2"
        
        log_debug "[ConfigManager] Aplicando tema Rofi: $theme_name"
        # Implementar lógica específica do Rofi
    }
    
    private _apply_wallpaper_theme() {
        local config_name="$1"
        local theme_name="$2"
        
        log_debug "[ConfigManager] Aplicando tema Wallpaper: $theme_name"
        # Implementar lógica específica do Wallpaper
    }
}

# Instanciar Configuration Manager global
config_manager="$(new ConfigManager)"