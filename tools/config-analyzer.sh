#!/bin/bash

# Configuration Discovery and Analysis Tool
# Analisa configurações existentes do Hyprland para planejar migração

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh"

# Configurações de análise
ANALYSIS_OUTPUT_DIR="$(dirname "${BASH_SOURCE[0]}")/../migration/analysis"
BACKUP_DIR="$HOME/.config/hypr-migration-backup"
CONFIG_ROOT="$HOME/.config"

# Estruturas esperadas do sistema atual
EXPECTED_DIRS=(
    "$CONFIG_ROOT/hypr"
    "$CONFIG_ROOT/waybar" 
    "$CONFIG_ROOT/rofi"
)

HYPR_FILES=(
    "$CONFIG_ROOT/hypr/hyprland.conf"
    "$CONFIG_ROOT/hypr/hyprpaper.conf"
    "$CONFIG_ROOT/hypr/monitors.conf"
    "$CONFIG_ROOT/hypr/workspaces.conf"
)

WAYBAR_FILES=(
    "$CONFIG_ROOT/waybar/config.jsonc"
    "$CONFIG_ROOT/waybar/style.css"
)

ROFI_FILES=(
    "$CONFIG_ROOT/rofi/config.rasi"
    "$CONFIG_ROOT/rofi/theme.rasi"
)

# Função principal de análise
main() {
    local action="${1:-analyze}"
    
    case "$action" in
        "analyze")
            analyze_configurations
            ;;
        "backup")
            backup_existing_configs
            ;;
        "report")
            generate_migration_report
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

# Analisar configurações existentes
analyze_configurations() {
    log_info "[ConfigAnalyzer] Iniciando análise das configurações existentes..."
    
    # Criar diretório de análise
    mkdir -p "$ANALYSIS_OUTPUT_DIR"
    
    # Gerar timestamp para esta análise
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    local analysis_file="$ANALYSIS_OUTPUT_DIR/analysis_$timestamp.txt"
    
    echo "# Análise de Configurações Existentes" > "$analysis_file"
    echo "# Gerado em: $(date)" >> "$analysis_file"
    echo "# Sistema: $(uname -a)" >> "$analysis_file"
    echo "" >> "$analysis_file"
    
    # Analisar estrutura de diretórios
    analyze_directory_structure "$analysis_file"
    
    # Analisar arquivos do Hyprland
    analyze_hyprland_configs "$analysis_file"
    
    # Analisar configurações do Waybar
    analyze_waybar_configs "$analysis_file"
    
    # Analisar configurações do Rofi
    analyze_rofi_configs "$analysis_file"
    
    # Analisar scripts existentes
    analyze_existing_scripts "$analysis_file"
    
    # Analisar dependências entre configurações
    analyze_config_dependencies "$analysis_file"
    
    # Gerar recomendações de migração
    generate_migration_recommendations "$analysis_file"
    
    log_info "[ConfigAnalyzer] Análise concluída: $analysis_file"
    
    # Mostrar resumo no console
    show_analysis_summary "$analysis_file"
}

# Analisar estrutura de diretórios
analyze_directory_structure() {
    local output_file="$1"
    
    echo "## Estrutura de Diretórios" >> "$output_file"
    echo "" >> "$output_file"
    
    for dir in "${EXPECTED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "✅ ENCONTRADO: $dir" >> "$output_file"
            
            # Listar conteúdo do diretório
            echo "   Conteúdo:" >> "$output_file"
            find "$dir" -type f -name "*.conf" -o -name "*.jsonc" -o -name "*.css" -o -name "*.rasi" -o -name "*.sh" 2>/dev/null | while read -r file; do
                local size="$(stat -c%s "$file" 2>/dev/null || echo "0")"
                echo "   - $(basename "$file") (${size} bytes)" >> "$output_file"
            done
            echo "" >> "$output_file"
        else
            echo "❌ NÃO ENCONTRADO: $dir" >> "$output_file"
        fi
    done
    
    echo "" >> "$output_file"
}

# Analisar configurações do Hyprland
analyze_hyprland_configs() {
    local output_file="$1"
    
    echo "## Configurações do Hyprland" >> "$output_file"
    echo "" >> "$output_file"
    
    for file in "${HYPR_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file" >> "$output_file"
            
            # Analisar conteúdo específico
            local line_count="$(wc -l < "$file" 2>/dev/null || echo "0")"
            echo "   - Linhas: $line_count" >> "$output_file"
            
            # Verificar imports/sources
            local source_count="$(grep -c "^source" "$file" 2>/dev/null || echo "0")"
            if [ "$source_count" -gt 0 ]; then
                echo "   - Sources encontrados: $source_count" >> "$output_file"
                grep "^source" "$file" 2>/dev/null | while read -r line; do
                    echo "     * $line" >> "$output_file"
                done
            fi
            
            # Verificar keybinds
            local bind_count="$(grep -c "^bind" "$file" 2>/dev/null || echo "0")"
            if [ "$bind_count" -gt 0 ]; then
                echo "   - Keybinds: $bind_count" >> "$output_file"
            fi
            
            # Verificar variáveis
            local var_count="$(grep -c "^\$" "$file" 2>/dev/null || echo "0")"
            if [ "$var_count" -gt 0 ]; then
                echo "   - Variáveis: $var_count" >> "$output_file"
            fi
            
        else
            echo "❌ $file" >> "$output_file"
        fi
        echo "" >> "$output_file"
    done
    
    # Verificar diretório UserConfigs se existe
    local userconfigs_dir="$CONFIG_ROOT/hypr/UserConfigs"
    if [ -d "$userconfigs_dir" ]; then
        echo "📁 Diretório UserConfigs encontrado:" >> "$output_file"
        find "$userconfigs_dir" -name "*.conf" 2>/dev/null | while read -r file; do
            echo "   - $(basename "$file")" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi
    
    # Verificar diretório de scripts
    local scripts_dir="$CONFIG_ROOT/hypr/scripts"
    if [ -d "$scripts_dir" ]; then
        echo "📁 Diretório de Scripts encontrado:" >> "$output_file"
        find "$scripts_dir" -name "*.sh" 2>/dev/null | while read -r file; do
            echo "   - $(basename "$file")" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi
}

# Analisar configurações do Waybar
analyze_waybar_configs() {
    local output_file="$1"
    
    echo "## Configurações do Waybar" >> "$output_file"
    echo "" >> "$output_file"
    
    for file in "${WAYBAR_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file" >> "$output_file"
            
            local size="$(stat -c%s "$file" 2>/dev/null || echo "0")"
            echo "   - Tamanho: ${size} bytes" >> "$output_file"
            
            case "$file" in
                *.jsonc)
                    # Verificar módulos no config JSON
                    if command -v python3 >/dev/null 2>&1; then
                        local modules="$(python3 -c "
import json, sys
try:
    with open('$file') as f:
        # Remove comments from JSONC
        content = ''
        for line in f:
            if '//' not in line:
                content += line
            else:
                content += line[:line.find('//')]
        data = json.loads(content)
        if 'modules-left' in data:
            print('Left:', ', '.join(data['modules-left']))
        if 'modules-center' in data:
            print('Center:', ', '.join(data['modules-center']))
        if 'modules-right' in data:
            print('Right:', ', '.join(data['modules-right']))
except:
    pass
" 2>/dev/null)"
                        if [ -n "$modules" ]; then
                            echo "   - Módulos configurados:" >> "$output_file"
                            echo "$modules" | while read -r line; do
                                echo "     * $line" >> "$output_file"
                            done
                        fi
                    fi
                    ;;
                *.css)
                    # Verificar seletores CSS
                    local selector_count="$(grep -c "^[.#]" "$file" 2>/dev/null || echo "0")"
                    echo "   - Seletores CSS: $selector_count" >> "$output_file"
                    ;;
            esac
        else
            echo "❌ $file" >> "$output_file"
        fi
        echo "" >> "$output_file"
    done
}

# Analisar configurações do Rofi
analyze_rofi_configs() {
    local output_file="$1"
    
    echo "## Configurações do Rofi" >> "$output_file"
    echo "" >> "$output_file"
    
    for file in "${ROFI_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file" >> "$output_file"
            
            local line_count="$(wc -l < "$file" 2>/dev/null || echo "0")"
            echo "   - Linhas: $line_count" >> "$output_file"
            
            # Verificar imports
            local import_count="$(grep -c "@import" "$file" 2>/dev/null || echo "0")"
            if [ "$import_count" -gt 0 ]; then
                echo "   - Imports: $import_count" >> "$output_file"
                grep "@import" "$file" 2>/dev/null | while read -r line; do
                    echo "     * $line" >> "$output_file"
                done
            fi
        else
            echo "❌ $file" >> "$output_file"
        fi
        echo "" >> "$output_file"
    done
    
    # Verificar diretório wallust se existe
    local wallust_dir="$CONFIG_ROOT/rofi/wallust"
    if [ -d "$wallust_dir" ]; then
        echo "📁 Diretório wallust encontrado:" >> "$output_file"
        find "$wallust_dir" -name "*.rasi" 2>/dev/null | while read -r file; do
            echo "   - $(basename "$file")" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi
}

# Analisar scripts existentes
analyze_existing_scripts() {
    local output_file="$1"
    
    echo "## Scripts Existentes" >> "$output_file"
    echo "" >> "$output_file"
    
    # Verificar scripts no diretório do projeto
    local project_scripts_dir="$(dirname "${BASH_SOURCE[0]}")/../scripts"
    if [ -d "$project_scripts_dir" ]; then
        echo "📁 Scripts do Projeto:" >> "$output_file"
        find "$project_scripts_dir" -name "*.sh" 2>/dev/null | while read -r file; do
            echo "   - $(basename "$file")" >> "$output_file"
        done
        echo "" >> "$output_file"
    fi
    
    # Verificar scripts na configuração do usuário
    local user_scripts_dir="$CONFIG_ROOT/hypr/scripts"
    if [ -d "$user_scripts_dir" ]; then
        echo "📁 Scripts do Usuário:" >> "$output_file"
        find "$user_scripts_dir" -name "*.sh" 2>/dev/null | while read -r file; do
            local script_name="$(basename "$file")"
            echo "   - $script_name" >> "$output_file"
            
            # Analisar dependências do script
            local deps="$(grep -o '\$[A-Za-z_][A-Za-z0-9_]*\|~/.config/[a-zA-Z0-9/_.-]*' "$file" 2>/dev/null | sort | uniq | head -3)"
            if [ -n "$deps" ]; then
                echo "     Dependências: $(echo "$deps" | tr '\n' ', ' | sed 's/,$//')" >> "$output_file"
            fi
        done
        echo "" >> "$output_file"
    fi
}

# Analisar dependências entre configurações
analyze_config_dependencies() {
    local output_file="$1"
    
    echo "## Dependências Entre Configurações" >> "$output_file"
    echo "" >> "$output_file"
    
    # Procurar referências cruzadas
    local all_config_files=()
    
    # Adicionar todos os arquivos encontrados
    for dir in "${EXPECTED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                all_config_files+=("$file")
            done < <(find "$dir" -type f \( -name "*.conf" -o -name "*.jsonc" -o -name "*.css" -o -name "*.rasi" -o -name "*.sh" \) -print0 2>/dev/null)
        fi
    done
    
    echo "📊 Análise de Referências Cruzadas:" >> "$output_file"
    
    for file in "${all_config_files[@]}"; do
        local refs="$(grep -o '~/.config/[a-zA-Z0-9/_.-]*\|\$[A-Za-z_][A-Za-z0-9_]*' "$file" 2>/dev/null | sort | uniq | wc -l)"
        if [ "$refs" -gt 0 ]; then
            echo "   - $(basename "$file"): $refs referências externas" >> "$output_file"
        fi
    done
    
    echo "" >> "$output_file"
}

# Gerar recomendações de migração
generate_migration_recommendations() {
    local output_file="$1"
    
    echo "## Recomendações de Migração" >> "$output_file"
    echo "" >> "$output_file"
    
    echo "### Prioridade Alta:" >> "$output_file"
    
    # Verificar se há configurações críticas
    if [ -f "$CONFIG_ROOT/hypr/hyprland.conf" ]; then
        echo "- ✅ Migrar hyprland.conf principal (arquivo central do sistema)" >> "$output_file"
    fi
    
    if [ -f "$CONFIG_ROOT/waybar/config.jsonc" ]; then
        echo "- ✅ Migrar configuração do Waybar (interface principal)" >> "$output_file"
    fi
    
    echo "" >> "$output_file"
    echo "### Prioridade Média:" >> "$output_file"
    
    if [ -f "$CONFIG_ROOT/rofi/config.rasi" ]; then
        echo "- ⚡ Migrar configuração do Rofi (launcher)" >> "$output_file"
    fi
    
    if [ -d "$CONFIG_ROOT/hypr/UserConfigs" ]; then
        echo "- ⚡ Migrar UserConfigs (personalizações do usuário)" >> "$output_file"
    fi
    
    echo "" >> "$output_file"
    echo "### Prioridade Baixa:" >> "$output_file"
    
    if [ -d "$CONFIG_ROOT/hypr/scripts" ]; then
        echo "- 🔧 Integrar scripts personalizados" >> "$output_file"
    fi
    
    echo "- 🎨 Migrar temas e cores personalizadas" >> "$output_file"
    
    echo "" >> "$output_file"
    echo "### Ações Recomendadas:" >> "$output_file"
    echo "1. Fazer backup completo das configurações atuais" >> "$output_file"
    echo "2. Iniciar migração com configurações críticas" >> "$output_file"
    echo "3. Testar sistema modular em paralelo" >> "$output_file"
    echo "4. Migrar configurações secundárias gradualmente" >> "$output_file"
    echo "5. Validar funcionamento após cada etapa" >> "$output_file"
    
    echo "" >> "$output_file"
}

# Fazer backup das configurações existentes
backup_existing_configs() {
    log_info "[ConfigAnalyzer] Iniciando backup das configurações existentes..."
    
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    local backup_full_dir="$BACKUP_DIR/full_backup_$timestamp"
    
    mkdir -p "$backup_full_dir"
    
    # Backup dos diretórios principais
    for dir in "${EXPECTED_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local dir_name="$(basename "$dir")"
            log_info "[ConfigAnalyzer] Fazendo backup de: $dir"
            cp -r "$dir" "$backup_full_dir/$dir_name" 2>/dev/null || {
                log_warn "[ConfigAnalyzer] Falha no backup de $dir"
            }
        fi
    done
    
    # Criar manifesto do backup
    echo "# Backup Manifest" > "$backup_full_dir/MANIFEST.txt"
    echo "# Created: $(date)" >> "$backup_full_dir/MANIFEST.txt"
    echo "# System: $(uname -a)" >> "$backup_full_dir/MANIFEST.txt"
    echo "" >> "$backup_full_dir/MANIFEST.txt"
    
    find "$backup_full_dir" -type f -exec ls -la {} \; >> "$backup_full_dir/MANIFEST.txt"
    
    log_info "[ConfigAnalyzer] Backup concluído em: $backup_full_dir"
    echo "Backup salvo em: $backup_full_dir"
}

# Mostrar resumo da análise
show_analysis_summary() {
    local analysis_file="$1"
    
    echo ""
    echo "=================================="
    echo "   RESUMO DA ANÁLISE"
    echo "=================================="
    echo ""
    
    # Contar arquivos encontrados
    local found_configs="$(grep -c "✅" "$analysis_file" 2>/dev/null || echo "0")"
    local missing_configs="$(grep -c "❌" "$analysis_file" 2>/dev/null || echo "0")"
    
    echo "📊 Configurações encontradas: $found_configs"
    echo "❌ Configurações faltando: $missing_configs"
    echo ""
    
    # Mostrar próximos passos
    echo "🔄 Próximos passos:"
    echo "1. Revisar análise completa: $analysis_file"
    echo "2. Fazer backup: $0 backup"
    echo "3. Executar migração: ../migration/migrate.sh"
    echo ""
}

# Gerar relatório de migração
generate_migration_report() {
    log_info "[ConfigAnalyzer] Gerando relatório de migração..."
    
    local latest_analysis="$(find "$ANALYSIS_OUTPUT_DIR" -name "analysis_*.txt" | sort | tail -1)"
    
    if [ -z "$latest_analysis" ] || [ ! -f "$latest_analysis" ]; then
        log_error "[ConfigAnalyzer] Nenhuma análise encontrada. Execute primeiro: $0 analyze"
        exit 1
    fi
    
    echo "Relatório baseado em: $latest_analysis"
    echo ""
    
    # Extrair informações do arquivo de análise
    grep -A 20 "## Recomendações de Migração" "$latest_analysis" || {
        echo "Não foram encontradas recomendações no arquivo de análise"
    }
}

# Mostrar ajuda
show_help() {
    echo "Uso: $0 <ação>"
    echo ""
    echo "Ações disponíveis:"
    echo "  analyze  - Analisar configurações existentes (padrão)"
    echo "  backup   - Fazer backup das configurações atuais"
    echo "  report   - Gerar relatório de migração"
    echo "  help     - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 analyze      # Analisar configurações"
    echo "  $0 backup       # Backup das configs atuais"
    echo "  $0 report       # Relatório de migração"
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi