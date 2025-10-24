#!/bin/bash

# Migration Script - Migra configurações existentes para o sistema modular
# Integra configurações tradicionais com o novo sistema de componentes

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh"

# Diretórios de configuração
PROJECT_ROOT="$(dirname "${BASH_SOURCE[0]}")/.."
LEGACY_HYPR_DIR="$PROJECT_ROOT/core/hypr"
LEGACY_WAYBAR_DIR="$PROJECT_ROOT/components/waybar" 
LEGACY_ROFI_DIR="$PROJECT_ROOT/components/rofi"
LEGACY_SCRIPTS_DIR="$PROJECT_ROOT/scripts"

# Diretórios do sistema modular
COMPONENTS_DIR="$PROJECT_ROOT/components"
SERVICES_DIR="$PROJECT_ROOT/services"
MIGRATION_DIR="$PROJECT_ROOT/migration"
BACKUP_DIR="$MIGRATION_DIR/backup"

# Status da migração
MIGRATION_STATUS_FILE="$MIGRATION_DIR/migration_status.conf"

# Função principal
main() {
    local action="${1:-migrate}"
    
    case "$action" in
        "analyze")
            analyze_legacy_configs
            ;;
        "migrate")
            migrate_configurations
            ;;
        "rollback")
            rollback_migration
            ;;
        "status")
            show_migration_status
            ;;
        "test")
            test_migration_compatibility
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

# Analisar configurações legadas
analyze_legacy_configs() {
    log_info "[Migration] Analisando configurações existentes..."
    
    mkdir -p "$MIGRATION_DIR"
    local analysis_file="$MIGRATION_DIR/legacy_analysis.txt"
    
    echo "# Análise de Configurações Legadas - $(date)" > "$analysis_file"
    echo "" >> "$analysis_file"
    
    # Analisar hyprland.conf principal
    analyze_hyprland_main_config "$analysis_file"
    
    # Analisar UserConfigs
    analyze_user_configs "$analysis_file"
    
    # Analisar configurações do Waybar
    analyze_waybar_legacy "$analysis_file"
    
    # Analisar configurações do Rofi  
    analyze_rofi_legacy "$analysis_file"
    
    # Analisar scripts existentes
    analyze_legacy_scripts "$analysis_file"
    
    log_info "[Migration] Análise concluída: $analysis_file"
    echo "Análise salva em: $analysis_file"
}

# Analisar configuração principal do Hyprland
analyze_hyprland_main_config() {
    local output_file="$1"
    
    echo "## Configuração Principal do Hyprland" >> "$output_file"
    echo "" >> "$output_file"
    
    if [ -f "$LEGACY_HYPR_DIR/hyprland.conf" ]; then
        echo "✅ hyprland.conf encontrado" >> "$output_file"
        
        # Analisar variáveis definidas
        local variables="$(grep '^\$' "$LEGACY_HYPR_DIR/hyprland.conf" | head -5)"
        echo "Variáveis definidas:" >> "$output_file"
        echo "$variables" | while read -r var; do
            echo "  - $var" >> "$output_file"
        done
        echo "" >> "$output_file"
        
        # Analisar sources
        local sources="$(grep '^source=' "$LEGACY_HYPR_DIR/hyprland.conf")"
        echo "Arquivos incluídos:" >> "$output_file"
        echo "$sources" | while read -r src; do
            echo "  - $src" >> "$output_file"
        done
        echo "" >> "$output_file"
        
    else
        echo "❌ hyprland.conf não encontrado" >> "$output_file"
    fi
}

# Analisar UserConfigs
analyze_user_configs() {
    local output_file="$1"
    
    echo "## UserConfigs (Configurações do Usuário)" >> "$output_file"
    echo "" >> "$output_file"
    
    if [ -d "$LEGACY_HYPR_DIR/UserConfigs" ]; then
        echo "📁 Diretório UserConfigs encontrado" >> "$output_file"
        
        find "$LEGACY_HYPR_DIR/UserConfigs" -name "*.conf" | while read -r file; do
            local filename="$(basename "$file")"
            local line_count="$(wc -l < "$file" 2>/dev/null || echo "0")"
            echo "  - $filename ($line_count linhas)" >> "$output_file"
            
            # Identificar tipo de configuração
            case "$filename" in
                "UserKeybinds.conf")
                    local bind_count="$(grep -c '^bind' "$file" 2>/dev/null || echo "0")"
                    echo "    * $bind_count keybinds definidos" >> "$output_file"
                    ;;
                "MyPrograms.conf")
                    local program_count="$(grep -c '^\$' "$file" 2>/dev/null || echo "0")"
                    echo "    * $program_count programas definidos" >> "$output_file"
                    ;;
                "Startup_Apps.conf")
                    local exec_count="$(grep -c '^exec' "$file" 2>/dev/null || echo "0")"
                    echo "    * $exec_count apps de inicialização" >> "$output_file"
                    ;;
            esac
        done
        echo "" >> "$output_file"
    else
        echo "❌ Diretório UserConfigs não encontrado" >> "$output_file"
    fi
}

# Analisar Waybar legado
analyze_waybar_legacy() {
    local output_file="$1"
    
    echo "## Configurações do Waybar" >> "$output_file"
    echo "" >> "$output_file"
    
    if [ -f "$LEGACY_WAYBAR_DIR/config.jsonc" ]; then
        echo "✅ config.jsonc encontrado" >> "$output_file"
        local size="$(stat -c%s "$LEGACY_WAYBAR_DIR/config.jsonc" 2>/dev/null || echo "0")"
        echo "  - Tamanho: ${size} bytes" >> "$output_file"
    fi
    
    if [ -f "$LEGACY_WAYBAR_DIR/style.css" ]; then
        echo "✅ style.css encontrado" >> "$output_file"
        local css_rules="$(grep -c '{' "$LEGACY_WAYBAR_DIR/style.css" 2>/dev/null || echo "0")"
        echo "  - Regras CSS: $css_rules" >> "$output_file"
    fi
    
    # Verificar módulos modulares
    local modules=("Modules" "ModulesCustom" "ModulesGroups" "ModulesWorkspaces")
    echo "Módulos modulares:" >> "$output_file"
    for module in "${modules[@]}"; do
        if [ -f "$LEGACY_WAYBAR_DIR/$module" ]; then
            echo "  ✅ $module" >> "$output_file"
        else
            echo "  ❌ $module" >> "$output_file"
        fi
    done
    
    echo "" >> "$output_file"
}

# Analisar Rofi legado
analyze_rofi_legacy() {
    local output_file="$1"
    
    echo "## Configurações do Rofi" >> "$output_file"
    echo "" >> "$output_file"
    
    if [ -f "$LEGACY_ROFI_DIR/config.rasi" ]; then
        echo "✅ config.rasi encontrado" >> "$output_file"
    fi
    
    if [ -f "$LEGACY_ROFI_DIR/theme.rasi" ]; then
        echo "✅ theme.rasi encontrado" >> "$output_file"
    fi
    
    if [ -f "$LEGACY_ROFI_DIR/shared-fonts.rasi" ]; then
        echo "✅ shared-fonts.rasi encontrado" >> "$output_file"
    fi
    
    # Verificar wallust
    if [ -d "$LEGACY_ROFI_DIR/wallust" ]; then
        echo "📁 Diretório wallust encontrado" >> "$output_file"
        find "$LEGACY_ROFI_DIR/wallust" -name "*.rasi" | while read -r file; do
            echo "  - $(basename "$file")" >> "$output_file"
        done
    fi
    
    echo "" >> "$output_file"
}

# Analisar scripts legados
analyze_legacy_scripts() {
    local output_file="$1"
    
    echo "## Scripts Existentes" >> "$output_file"
    echo "" >> "$output_file"
    
    if [ -d "$LEGACY_SCRIPTS_DIR" ]; then
        echo "📁 Diretório scripts encontrado" >> "$output_file"
        
        find "$LEGACY_SCRIPTS_DIR" -name "*.sh" | while read -r script; do
            local script_name="$(basename "$script")"
            echo "  - $script_name" >> "$output_file"
            
            # Verificar se usa variáveis ou paths específicos
            if grep -q '\$Scripts\|\$UserConfigs\|~/.config/hypr' "$script" 2>/dev/null; then
                echo "    ⚠️  Usa paths legados (precisa adaptação)" >> "$output_file"
            fi
        done
        echo "" >> "$output_file"
    else
        echo "❌ Diretório scripts não encontrado" >> "$output_file"
    fi
}

# Migrar configurações
migrate_configurations() {
    log_info "[Migration] Iniciando migração das configurações..."
    
    # Criar estrutura de migração
    mkdir -p "$MIGRATION_DIR" "$BACKUP_DIR"
    
    # Fazer backup das configurações atuais
    create_migration_backup
    
    # Iniciar processo de migração
    init_migration_status
    
    # Migrar componente por componente
    migrate_hyprland_component
    migrate_waybar_component  
    migrate_rofi_component
    migrate_scripts_component
    
    # Criar bridges de compatibilidade
    create_compatibility_bridges
    
    # Finalizar migração
    finalize_migration
    
    log_info "[Migration] Migração concluída!"
    show_migration_summary
}

# Criar backup antes da migração
create_migration_backup() {
    log_info "[Migration] Criando backup das configurações..."
    
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_full_dir="$BACKUP_DIR/pre_migration_$timestamp"
    
    mkdir -p "$backup_full_dir"
    
    # Backup das configurações legadas
    if [ -d "$LEGACY_HYPR_DIR" ]; then
        cp -r "$LEGACY_HYPR_DIR" "$backup_full_dir/hypr_legacy"
    fi
    
    if [ -d "$LEGACY_WAYBAR_DIR" ]; then
        cp -r "$LEGACY_WAYBAR_DIR" "$backup_full_dir/waybar_legacy"
    fi
    
    if [ -d "$LEGACY_ROFI_DIR" ]; then
        cp -r "$LEGACY_ROFI_DIR" "$backup_full_dir/rofi_legacy"
    fi
    
    if [ -d "$LEGACY_SCRIPTS_DIR" ]; then
        cp -r "$LEGACY_SCRIPTS_DIR" "$backup_full_dir/scripts_legacy"
    fi
    
    # Salvar paths no status
    echo "BACKUP_PATH=$backup_full_dir" >> "$MIGRATION_STATUS_FILE"
    
    log_info "[Migration] Backup salvo em: $backup_full_dir"
}

# Inicializar status da migração
init_migration_status() {
    echo "# Migration Status - $(date)" > "$MIGRATION_STATUS_FILE"
    echo "MIGRATION_STARTED=$(date '+%Y-%m-%d %H:%M:%S')" >> "$MIGRATION_STATUS_FILE"
    echo "MIGRATION_VERSION=3.0.0" >> "$MIGRATION_STATUS_FILE"
    echo "" >> "$MIGRATION_STATUS_FILE"
}

# Migrar componente Hyprland
migrate_hyprland_component() {
    log_info "[Migration] Migrando configurações do Hyprland..."
    
    # Criar estrutura para o componente Hyprland
    local hypr_component_dir="$COMPONENTS_DIR/hyprland"
    mkdir -p "$hypr_component_dir"
    
    # Copiar configurações base mantendo a estrutura modular
    if [ -f "$LEGACY_HYPR_DIR/hyprland.conf" ]; then
        # Adaptar hyprland.conf para usar o novo sistema
        create_adapted_hyprland_config "$hypr_component_dir"
    fi
    
    # Migrar UserConfigs
    if [ -d "$LEGACY_HYPR_DIR/UserConfigs" ]; then
        cp -r "$LEGACY_HYPR_DIR/UserConfigs" "$hypr_component_dir/"
    fi
    
    # Copiar configurações específicas
    for config in "monitors.conf" "workspaces.conf" "hyprpaper.conf"; do
        if [ -f "$LEGACY_HYPR_DIR/$config" ]; then
            cp "$LEGACY_HYPR_DIR/$config" "$hypr_component_dir/"
        fi
    done
    
    # Criar componente Hyprland
    create_hyprland_component "$hypr_component_dir"
    
    echo "HYPRLAND_MIGRATED=true" >> "$MIGRATION_STATUS_FILE"
    log_info "[Migration] Hyprland migrado com sucesso"
}

# Migrar componente Waybar
migrate_waybar_component() {
    log_info "[Migration] Migrando configurações do Waybar..."
    
    # O Waybar já está em components/waybar, então apenas validar
    if [ -f "$LEGACY_WAYBAR_DIR/config.jsonc" ]; then
        # Waybar já está na estrutura modular
        echo "WAYBAR_MIGRATED=true (already modular)" >> "$MIGRATION_STATUS_FILE"
        log_info "[Migration] Waybar já está na estrutura modular"
    else
        echo "WAYBAR_MIGRATED=false (missing config)" >> "$MIGRATION_STATUS_FILE"
        log_warn "[Migration] Configuração do Waybar não encontrada"
    fi
}

# Migrar componente Rofi
migrate_rofi_component() {
    log_info "[Migration] Migrando configurações do Rofi..."
    
    # O Rofi já está em components/rofi, então apenas validar
    if [ -f "$LEGACY_ROFI_DIR/config.rasi" ]; then
        # Rofi já está na estrutura modular
        echo "ROFI_MIGRATED=true (already modular)" >> "$MIGRATION_STATUS_FILE"
        log_info "[Migration] Rofi já está na estrutura modular"
    else
        echo "ROFI_MIGRATED=false (missing config)" >> "$MIGRATION_STATUS_FILE"
        log_warn "[Migration] Configuração do Rofi não encontrada"
    fi
}

# Migrar scripts
migrate_scripts_component() {
    log_info "[Migration] Migrando scripts existentes..."
    
    if [ ! -d "$LEGACY_SCRIPTS_DIR" ]; then
        log_warn "[Migration] Diretório de scripts não encontrado"
        return 1
    fi
    
    # Criar diretório para scripts adaptados
    local adapted_scripts_dir="$COMPONENTS_DIR/scripts"
    mkdir -p "$adapted_scripts_dir"
    
    # Copiar e adaptar cada script
    find "$LEGACY_SCRIPTS_DIR" -name "*.sh" | while read -r script; do
        local script_name="$(basename "$script")"
        local adapted_script="$adapted_scripts_dir/$script_name"
        
        log_info "[Migration] Adaptando script: $script_name"
        
        # Copiar script e adaptar paths
        cp "$script" "$adapted_script"
        
        # Adaptar paths comuns
        sed -i 's|~/.config/hypr/scripts|'"$PROJECT_ROOT"'/components/scripts|g' "$adapted_script" 2>/dev/null || true
        sed -i 's|\$Scripts|'"$PROJECT_ROOT"'/components/scripts|g' "$adapted_script" 2>/dev/null || true
        sed -i 's|~/.config/hypr/UserConfigs|'"$PROJECT_ROOT"'/components/hyprland/UserConfigs|g' "$adapted_script" 2>/dev/null || true
        
        chmod +x "$adapted_script"
    done
    
    echo "SCRIPTS_MIGRATED=true" >> "$MIGRATION_STATUS_FILE"
    log_info "[Migration] Scripts migrados com sucesso"
}

# Criar bridges de compatibilidade
create_compatibility_bridges() {
    log_info "[Migration] Criando bridges de compatibilidade..."
    
    local bridges_dir="$MIGRATION_DIR/compatibility"
    mkdir -p "$bridges_dir"
    
    # Bridge para hyprland.conf que integra legado com modular
    create_hyprland_bridge "$bridges_dir"
    
    # Bridge para scripts que redirecionam para componentes
    create_scripts_bridge "$bridges_dir"
    
    echo "COMPATIBILITY_BRIDGES=true" >> "$MIGRATION_STATUS_FILE"
    log_info "[Migration] Bridges de compatibilidade criados"
}

# Criar hyprland.conf adaptado
create_adapted_hyprland_config() {
    local output_dir="$1"
    local output_file="$output_dir/hyprland.conf"
    
    cat > "$output_file" << 'EOF'
# Hyprland Configuration - Modular System
# Generated by migration script

# Variables for modular system
$ComponentsDir = ~/.config/hypr-components
$LegacyScripts = ~/.config/hypr/scripts
$UserConfigsHypr = ~/.config/hypr-components/hyprland/UserConfigs

####################
### NWG-DISPLAYS ###
####################
source = ~/.config/hypr-components/hyprland/monitors.conf
source = ~/.config/hypr-components/hyprland/workspaces.conf

###################
### MY PROGRAMS ###
###################
source = $UserConfigsHypr/MyPrograms.conf

#################
### AUTOSTART ###
#################
source = $UserConfigsHypr/Startup_Apps.conf

#############################
### ENVIRONMENT VARIABLES ###
#############################
source = $UserConfigsHypr/ENVariables.conf

#####################
### LOOK AND FEEL ###
#####################
source = $UserConfigsHypr/UserDecorations.conf
source = $UserConfigsHypr/UserAnimations.conf

#############
### INPUT ###
#############
source = $UserConfigsHypr/UserInput.conf

###################
### KEYBINDINGS ###
###################
source = $UserConfigsHypr/UserKeybinds.conf

##############################
###      WINDOWS RULES     ###
##############################
source = $UserConfigsHypr/WindowRules.conf
EOF
    
    log_info "[Migration] hyprland.conf adaptado criado"
}

# Criar componente Hyprland
create_hyprland_component() {
    local component_dir="$1"
    local component_file="$component_dir/hyprland-component.sh"
    
    cat > "$component_file" << 'EOF'
#!/bin/bash

# Hyprland Component - Gerencia configurações do Hyprland
source "$(dirname "${BASH_SOURCE[0]}")/../../core/event-system.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logger.sh"

class HyprlandComponent {
    private component_dir="$(dirname "${BASH_SOURCE[0]}")"
    private config_file="$component_dir/hyprland.conf"
    
    public init() {
        log_info "[HyprlandComponent] Inicializando componente Hyprland..."
        
        # Verificar se configurações existem
        if [ ! -f "$config_file" ]; then
            log_error "[HyprlandComponent] Configuração não encontrada: $config_file"
            return 1
        fi
        
        register_event_handler "wallpaper.changed" "_handle_wallpaper_change"
        register_event_handler "theme.changed" "_handle_theme_change"
        
        log_info "[HyprlandComponent] Hyprland inicializado"
        return 0
    }
    
    public validate() {
        log_info "[HyprlandComponent] Validando configuração..."
        
        # Verificar arquivos essenciais
        local required_files=("hyprland.conf" "UserConfigs/UserKeybinds.conf")
        
        for file in "${required_files[@]}"; do
            if [ ! -f "$component_dir/$file" ]; then
                log_error "[HyprlandComponent] Arquivo obrigatório não encontrado: $file"
                return 1
            fi
        done
        
        return 0
    }
    
    public apply_theme() {
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
    
    public cleanup() {
        log_info "[HyprlandComponent] Limpeza do Hyprland concluída"
        return 0
    }
    
    public health_check() {
        if [ -f "$config_file" ] && [ -d "$component_dir/UserConfigs" ]; then
            echo "healthy"
        else
            echo "unhealthy"
        fi
        return 0
    }
    
    private _handle_wallpaper_change() {
        log_info "[HyprlandComponent] Wallpaper alterado, atualizando hyprpaper"
    }
    
    private _handle_theme_change() {
        local event_data="$1"
        log_info "[HyprlandComponent] Tema alterado: $event_data"
    }
}

# Instanciar se executado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    hyprland_component="$(new HyprlandComponent)"
    "$hyprland_component" "$@"
fi
EOF
    
    chmod +x "$component_file"
    log_info "[Migration] Componente Hyprland criado"
}

# Criar bridge do Hyprland
create_hyprland_bridge() {
    local bridges_dir="$1"
    local bridge_file="$bridges_dir/hyprland-bridge.conf"
    
    cat > "$bridge_file" << EOF
# Hyprland Bridge Configuration
# Permite compatibilidade entre sistema legado e modular

# Redirecionamentos de paths
\$UserConfigs = $PROJECT_ROOT/components/hyprland/UserConfigs  
\$Scripts = $PROJECT_ROOT/components/scripts
\$UserConfigsHypr = $PROJECT_ROOT/components/hyprland/UserConfigs

# Include configuração modular
source = $PROJECT_ROOT/components/hyprland/hyprland.conf
EOF
    
    log_info "[Migration] Bridge do Hyprland criado"
}

# Criar bridge de scripts
create_scripts_bridge() {
    local bridges_dir="$1"
    local bridge_script="$bridges_dir/script-bridge.sh"
    
    cat > "$bridge_script" << EOF
#!/bin/bash

# Script Bridge - Redirecionador de scripts legados para modulares
# Permite que scripts antigos funcionem com a nova estrutura

LEGACY_SCRIPT_NAME="\$(basename "\$0")"
MODULAR_SCRIPT_PATH="$PROJECT_ROOT/components/scripts/\$LEGACY_SCRIPT_NAME"

if [ -f "\$MODULAR_SCRIPT_PATH" ]; then
    echo "Redirecionando para script modular: \$LEGACY_SCRIPT_NAME" >&2
    exec "\$MODULAR_SCRIPT_PATH" "\$@"
else
    echo "Script não encontrado na estrutura modular: \$LEGACY_SCRIPT_NAME" >&2
    exit 1
fi
EOF
    
    chmod +x "$bridge_script"
    log_info "[Migration] Bridge de scripts criado"
}

# Finalizar migração
finalize_migration() {
    echo "MIGRATION_COMPLETED=$(date '+%Y-%m-%d %H:%M:%S')" >> "$MIGRATION_STATUS_FILE"
    echo "MIGRATION_STATUS=success" >> "$MIGRATION_STATUS_FILE"
    
    # Criar arquivo de instruções pós-migração
    create_post_migration_instructions
    
    emit_event "migration.completed" "{\"timestamp\": \"$(date)\"}"
}

# Criar instruções pós-migração
create_post_migration_instructions() {
    local instructions_file="$MIGRATION_DIR/post_migration_instructions.md"
    
    cat > "$instructions_file" << 'EOF'
# Instruções Pós-Migração

## ✅ Migração Concluída

A migração para o sistema modular foi concluída com sucesso!

## 📋 Próximos Passos

1. **Testar Sistema Modular**
   ```bash
   ./tools/system-controller.sh start
   ```

2. **Verificar Saúde do Sistema**
   ```bash
   ./tools/system-controller.sh health
   ```

3. **Aplicar Tema**
   ```bash
   ./tools/system-controller.sh theme default
   ```

## 🔄 Rollback (se necessário)

Se algo não funcionar, você pode reverter:
```bash
./tools/migrate.sh rollback
```

## 📁 Estrutura Atualizada

- ✅ Configurações migradas para `components/`
- ✅ Scripts adaptados em `components/scripts/`
- ✅ Bridges de compatibilidade criados
- ✅ Backup salvo em `migration/backup/`

## 🔧 Configurações Manuais

Alguns ajustes podem ser necessários:
- Verificar paths em scripts personalizados
- Ajustar keybinds se necessário
- Configurar temas específicos
EOF

    log_info "[Migration] Instruções pós-migração criadas: $instructions_file"
}

# Mostrar status da migração
show_migration_status() {
    if [ ! -f "$MIGRATION_STATUS_FILE" ]; then
        echo "Nenhuma migração foi executada ainda"
        return 0
    fi
    
    echo "=================================="
    echo "    STATUS DA MIGRAÇÃO"
    echo "=================================="
    echo ""
    
    source "$MIGRATION_STATUS_FILE" 2>/dev/null || {
        echo "Erro ao ler status da migração"
        return 1
    }
    
    echo "📅 Iniciada: ${MIGRATION_STARTED:-"N/A"}"
    echo "📅 Concluída: ${MIGRATION_COMPLETED:-"Em andamento"}"
    echo "📦 Versão: ${MIGRATION_VERSION:-"N/A"}"
    echo "📁 Backup: ${BACKUP_PATH:-"N/A"}"
    echo ""
    
    echo "Componentes migrados:"
    echo "  - Hyprland: ${HYPRLAND_MIGRATED:-"Não"}"
    echo "  - Waybar: ${WAYBAR_MIGRATED:-"Não"}"
    echo "  - Rofi: ${ROFI_MIGRATED:-"Não"}"  
    echo "  - Scripts: ${SCRIPTS_MIGRATED:-"Não"}"
    echo ""
    
    echo "Recursos adicionais:"
    echo "  - Bridges: ${COMPATIBILITY_BRIDGES:-"Não"}"
    echo "  - Status: ${MIGRATION_STATUS:-"unknown"}"
}

# Mostrar resumo da migração
show_migration_summary() {
    echo ""
    echo "=================================="
    echo "    MIGRAÇÃO CONCLUÍDA"  
    echo "=================================="
    echo ""
    echo "✅ Configurações migradas com sucesso"
    echo "✅ Bridges de compatibilidade criados"
    echo "✅ Backup realizado"
    echo ""
    echo "📋 Próximos passos:"
    echo "1. Testar: ./tools/system-controller.sh start"
    echo "2. Status: ./tools/migrate.sh status"
    echo "3. Instruções: cat migration/post_migration_instructions.md"
    echo ""
}

# Rollback da migração
rollback_migration() {
    log_info "[Migration] Iniciando rollback da migração..."
    
    if [ ! -f "$MIGRATION_STATUS_FILE" ]; then
        log_error "[Migration] Nenhuma migração para fazer rollback"
        exit 1
    fi
    
    source "$MIGRATION_STATUS_FILE" 2>/dev/null || {
        log_error "[Migration] Erro ao ler status da migração"
        exit 1
    }
    
    if [ -z "$BACKUP_PATH" ] || [ ! -d "$BACKUP_PATH" ]; then
        log_error "[Migration] Backup não encontrado para rollback"
        exit 1
    fi
    
    echo "⚠️  ATENÇÃO: Isto irá reverter todas as mudanças da migração!"
    echo "Backup será restaurado de: $BACKUP_PATH"
    echo ""
    read -p "Continuar? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rollback cancelado"
        exit 0
    fi
    
    # Restaurar backups
    log_info "[Migration] Restaurando configurações do backup..."
    
    # Remover estrutura modular
    [ -d "$COMPONENTS_DIR/hyprland" ] && rm -rf "$COMPONENTS_DIR/hyprland"
    [ -d "$COMPONENTS_DIR/scripts" ] && rm -rf "$COMPONENTS_DIR/scripts"
    
    # Restaurar configurações legadas se necessário
    if [ -d "$BACKUP_PATH/hypr_legacy" ]; then
        cp -r "$BACKUP_PATH/hypr_legacy" "$LEGACY_HYPR_DIR"
    fi
    
    # Marcar rollback no status
    echo "ROLLBACK_DATE=$(date '+%Y-%m-%d %H:%M:%S')" >> "$MIGRATION_STATUS_FILE"
    echo "MIGRATION_STATUS=rolled_back" >> "$MIGRATION_STATUS_FILE"
    
    log_info "[Migration] Rollback concluído"
    echo "✅ Rollback realizado com sucesso"
}

# Testar compatibilidade da migração
test_migration_compatibility() {
    log_info "[Migration] Testando compatibilidade pós-migração..."
    
    local test_results=()
    
    # Testar se componentes foram criados
    if [ -d "$COMPONENTS_DIR/hyprland" ]; then
        test_results+=("✅ Componente Hyprland criado")
    else
        test_results+=("❌ Componente Hyprland não encontrado")
    fi
    
    # Testar se scripts foram adaptados
    if [ -d "$COMPONENTS_DIR/scripts" ]; then
        local script_count="$(find "$COMPONENTS_DIR/scripts" -name "*.sh" | wc -l)"
        test_results+=("✅ Scripts adaptados: $script_count")
    else
        test_results+=("❌ Scripts não adaptados")
    fi
    
    # Testar System Controller
    if [ -f "$PROJECT_ROOT/tools/system-controller.sh" ]; then
        if "$PROJECT_ROOT/tools/system-controller.sh" status >/dev/null 2>&1; then
            test_results+=("✅ System Controller funcional")
        else
            test_results+=("⚠️  System Controller com problemas")
        fi
    fi
    
    echo "Resultado dos testes:"
    printf '%s\n' "${test_results[@]}"
}

# Mostrar ajuda
show_help() {
    echo "Uso: $0 <ação>"
    echo ""
    echo "Ações disponíveis:"
    echo "  analyze   - Analisar configurações legadas"
    echo "  migrate   - Migrar para sistema modular (padrão)"
    echo "  rollback  - Reverter migração"
    echo "  status    - Mostrar status da migração"
    echo "  test      - Testar compatibilidade"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 analyze      # Analisar configs atuais"
    echo "  $0 migrate      # Executar migração"
    echo "  $0 status       # Ver status"
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi