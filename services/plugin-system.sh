#!/bin/bash

# Plugin System - Sistema de plugins extensível
# Gerencia descoberta, carregamento, hooks e segurança de plugins

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh" 2>/dev/null || true
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Variáveis do Plugin System
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$PROJECT_ROOT/plugins"
PLUGIN_CONFIG="$PROJECT_ROOT/config/plugins.conf"
PLUGIN_DATA_DIR="$PROJECT_ROOT/data/plugins"
PLUGIN_CACHE_DIR="$PLUGIN_DATA_DIR/cache"
PLUGIN_SECURITY_DIR="$PLUGIN_DATA_DIR/security"

# Estado do plugin system
declare -A loaded_plugins
declare -A plugin_metadata
declare -A plugin_hooks
declare -A plugin_config
declare -A plugin_security_status
is_initialized=false

# Hook points disponíveis
declare -a available_hooks=(
    "system.init"
    "system.startup"
    "system.shutdown"
    "theme.changed"
    "wallpaper.changed"
    "component.loaded"
    "component.failed"
    "user.action"
    "monitor.alert"
)

# Inicializar Plugin System
plugin_system_init() {
    log_info "[PluginSystem] Inicializando Plugin System..."
    
    # Criar estrutura necessária
    plugin_system_create_structure
    
    # Carregar configuração
    plugin_system_load_config
    
    # Registrar hooks no event system
    plugin_system_register_hooks
    
    # Descobrir e validar plugins
    plugin_system_discover_plugins
    
    is_initialized=true
    log_info "[PluginSystem] Plugin System inicializado"
    return 0
}

# Criar estrutura necessária
plugin_system_create_structure() {
    mkdir -p "$PLUGINS_DIR"/{core,user,themes,integrations}
    mkdir -p "$PLUGIN_DATA_DIR"/{cache,security,logs}
    mkdir -p "$(dirname "$PLUGIN_CONFIG")"
    
    # Criar configuração padrão se não existir
    if [ ! -f "$PLUGIN_CONFIG" ]; then
        plugin_system_create_default_config
    fi
    
    # Criar template de plugin se diretório estiver vazio
    if [ ! "$(ls -A "$PLUGINS_DIR" 2>/dev/null)" ]; then
        plugin_system_create_plugin_template
    fi
}

# Criar configuração padrão
plugin_system_create_default_config() {
    cat > "$PLUGIN_CONFIG" << 'EOF'
# Plugin System Configuration

# Segurança
ENABLE_PLUGIN_SECURITY=true
ALLOW_UNSIGNED_PLUGINS=false
REQUIRE_PLUGIN_VALIDATION=true
SANDBOX_PLUGINS=true

# Descoberta automática
AUTO_DISCOVER_PLUGINS=true
PLUGIN_DIRECTORIES=(
    "plugins/core"
    "plugins/user"
    "plugins/themes"
    "plugins/integrations"
)

# Carregamento
LOAD_PLUGINS_ON_STARTUP=true
PARALLEL_PLUGIN_LOADING=false
PLUGIN_LOAD_TIMEOUT=30

# Cache e performance
ENABLE_PLUGIN_CACHE=true
CACHE_PLUGIN_METADATA=true
PRELOAD_CRITICAL_PLUGINS=true

# Logs e debug
PLUGIN_DEBUG_MODE=false
LOG_PLUGIN_EVENTS=true
LOG_HOOK_EXECUTION=false

# Plugins habilitados por padrão
ENABLED_PLUGINS=(
    "system-monitor"
    "theme-manager"
    "wallpaper-engine"
)
EOF

    log_info "[PluginSystem] Configuração padrão criada"
}

# Criar template de plugin
plugin_system_create_plugin_template() {
    local template_dir="$PLUGINS_DIR/templates"
    mkdir -p "$template_dir"
    
    # Plugin template básico
    cat > "$template_dir/basic-plugin.sh" << 'EOF'
#!/bin/bash

# Template de Plugin Básico
# Este é um template para criação de novos plugins

# Metadados do Plugin (obrigatório)
PLUGIN_NAME="basic-plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Template básico para plugins"
PLUGIN_AUTHOR="Sistema"
PLUGIN_CATEGORY="template"
PLUGIN_DEPENDENCIES=""
PLUGIN_HOOKS="system.init,system.startup"

# Configuração do Plugin
PLUGIN_CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/config.conf"

# Inicializar plugin
plugin_init() {
    echo "[BasicPlugin] Plugin inicializado"
    return 0
}

# Limpar recursos do plugin
plugin_cleanup() {
    echo "[BasicPlugin] Plugin limpo"
    return 0
}

# Hook: System Init
hook_system_init() {
    local event_data="$1"
    echo "[BasicPlugin] Sistema inicializando: $event_data"
}

# Hook: System Startup
hook_system_startup() {
    local event_data="$1"
    echo "[BasicPlugin] Sistema iniciado: $event_data"
}

# Configuração personalizada do plugin
plugin_configure() {
    echo "[BasicPlugin] Configuração do plugin"
    echo "Opções disponíveis:"
    echo "1. Habilitar feature A"
    echo "2. Configurar feature B"
}

# Status do plugin
plugin_status() {
    echo "=================================="
    echo "    $PLUGIN_NAME v$PLUGIN_VERSION"
    echo "=================================="
    echo "Status: Ativo"
    echo "Hooks: $PLUGIN_HOOKS"
    echo "Configuração: $PLUGIN_CONFIG_FILE"
}

# Health check do plugin
plugin_health_check() {
    # Implementar verificações específicas
    echo "healthy"
    return 0
}

# Função principal do plugin
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init") plugin_init ;;
        "cleanup") plugin_cleanup ;;
        "configure") plugin_configure ;;
        "status") plugin_status ;;
        "health_check") plugin_health_check ;;
        "hook_"*) 
            local hook_name="${action#hook_}"
            local hook_function="hook_$(echo "$hook_name" | tr '.' '_')"
            if declare -f "$hook_function" >/dev/null; then
                "$hook_function" "$2"
            fi
            ;;
        *)
            echo "Plugin Commands:"
            echo "  init         - Inicializar plugin"
            echo "  cleanup      - Limpar recursos"
            echo "  configure    - Configurar plugin"
            echo "  status       - Status do plugin"
            echo "  health_check - Verificar saúde"
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF

    chmod +x "$template_dir/basic-plugin.sh"
    
    # Plugin template avançado
    cat > "$template_dir/advanced-plugin.sh" << 'EOF'
#!/bin/bash

# Template de Plugin Avançado
# Template com recursos avançados e melhores práticas

# Metadados do Plugin (obrigatório)
PLUGIN_NAME="advanced-plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Template avançado com recursos completos"
PLUGIN_AUTHOR="Sistema"
PLUGIN_CATEGORY="template"
PLUGIN_DEPENDENCIES="basic-plugin"
PLUGIN_HOOKS="system.init,theme.changed,user.action"
PLUGIN_API_VERSION="1.0"
PLUGIN_LICENSE="MIT"

# Configurações avançadas
PLUGIN_DATA_DIR="$(dirname "${BASH_SOURCE[0]}")/data"
PLUGIN_CONFIG_FILE="$PLUGIN_DATA_DIR/config.json"
PLUGIN_STATE_FILE="$PLUGIN_DATA_DIR/state.json"
PLUGIN_LOG_FILE="$PLUGIN_DATA_DIR/plugin.log"

# Estado interno do plugin
declare -A plugin_state
plugin_initialized=false

# Utilitários do plugin
plugin_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] [AdvancedPlugin] $message" >> "$PLUGIN_LOG_FILE"
}

plugin_save_state() {
    mkdir -p "$PLUGIN_DATA_DIR"
    {
        echo "{"
        echo "  \"initialized\": $plugin_initialized,"
        echo "  \"last_update\": \"$(date -Iseconds)\","
        echo "  \"version\": \"$PLUGIN_VERSION\""
        echo "}"
    } > "$PLUGIN_STATE_FILE"
}

plugin_load_state() {
    if [ -f "$PLUGIN_STATE_FILE" ]; then
        # Simular carregamento de JSON (versão simplificada)
        local last_version
        last_version="$(grep '"version"' "$PLUGIN_STATE_FILE" | cut -d'"' -f4)"
        if [ "$last_version" != "$PLUGIN_VERSION" ]; then
            plugin_log "INFO" "Detectada mudança de versão: $last_version -> $PLUGIN_VERSION"
            plugin_migrate_data "$last_version" "$PLUGIN_VERSION"
        fi
    fi
}

plugin_migrate_data() {
    local old_version="$1"
    local new_version="$2"
    plugin_log "INFO" "Migrando dados da versão $old_version para $new_version"
    # Implementar lógica de migração específica
}

# Inicialização avançada
plugin_init() {
    plugin_log "INFO" "Inicializando plugin avançado..."
    
    # Criar estrutura necessária
    mkdir -p "$PLUGIN_DATA_DIR"
    
    # Carregar estado anterior
    plugin_load_state
    
    # Carregar configuração
    plugin_load_config
    
    # Validar dependências
    if ! plugin_validate_dependencies; then
        plugin_log "ERROR" "Falha na validação de dependências"
        return 1
    fi
    
    plugin_initialized=true
    plugin_save_state
    
    plugin_log "INFO" "Plugin inicializado com sucesso"
    return 0
}

plugin_load_config() {
    if [ ! -f "$PLUGIN_CONFIG_FILE" ]; then
        plugin_create_default_config
    fi
    
    # Carregar configuração (versão simplificada)
    if [ -f "$PLUGIN_CONFIG_FILE" ]; then
        plugin_log "INFO" "Configuração carregada"
    fi
}

plugin_create_default_config() {
    cat > "$PLUGIN_CONFIG_FILE" << 'EOF'
{
    "enabled": true,
    "features": {
        "feature_a": true,
        "feature_b": false,
        "debug_mode": false
    },
    "settings": {
        "update_interval": 30,
        "max_retries": 3,
        "timeout": 10
    }
}
EOF
    plugin_log "INFO" "Configuração padrão criada"
}

plugin_validate_dependencies() {
    if [ -n "$PLUGIN_DEPENDENCIES" ]; then
        IFS=',' read -ra deps <<< "$PLUGIN_DEPENDENCIES"
        for dep in "${deps[@]}"; do
            dep="$(echo "$dep" | xargs)"  # trim whitespace
            if ! plugin_system_is_plugin_loaded "$dep" 2>/dev/null; then
                plugin_log "ERROR" "Dependência não encontrada: $dep"
                return 1
            fi
        done
    fi
    return 0
}

# Hooks avançados
hook_system_init() {
    local event_data="$1"
    plugin_log "INFO" "Hook system.init executado: $event_data"
    
    # Lógica específica do hook
    plugin_handle_system_init "$event_data"
}

hook_theme_changed() {
    local event_data="$1"
    plugin_log "INFO" "Hook theme.changed executado: $event_data"
    
    # Reagir à mudança de tema
    plugin_handle_theme_change "$event_data"
}

hook_user_action() {
    local event_data="$1"
    plugin_log "INFO" "Hook user.action executado: $event_data"
    
    # Processar ação do usuário
    plugin_handle_user_action "$event_data"
}

# Handlers específicos
plugin_handle_system_init() {
    local event_data="$1"
    plugin_log "DEBUG" "Processando inicialização do sistema"
}

plugin_handle_theme_change() {
    local event_data="$1"
    plugin_log "DEBUG" "Processando mudança de tema"
}

plugin_handle_user_action() {
    local event_data="$1"
    plugin_log "DEBUG" "Processando ação do usuário"
}

# Limpeza avançada
plugin_cleanup() {
    plugin_log "INFO" "Iniciando limpeza do plugin..."
    
    # Salvar estado final
    plugin_save_state
    
    # Limpar recursos temporários
    find "$PLUGIN_DATA_DIR" -name "*.tmp" -delete 2>/dev/null || true
    
    plugin_initialized=false
    plugin_log "INFO" "Plugin limpo com sucesso"
    return 0
}

# API do plugin
plugin_api_call() {
    local method="$1"
    shift
    local params="$*"
    
    case "$method" in
        "get_status")
            echo "{\"status\": \"active\", \"version\": \"$PLUGIN_VERSION\"}"
            ;;
        "get_config")
            if [ -f "$PLUGIN_CONFIG_FILE" ]; then
                cat "$PLUGIN_CONFIG_FILE"
            else
                echo "{}"
            fi
            ;;
        "set_config")
            plugin_log "INFO" "Configuração atualizada via API"
            # Implementar lógica de atualização
            ;;
        *)
            plugin_log "WARN" "Método de API desconhecido: $method"
            return 1
            ;;
    esac
}

# Status detalhado
plugin_status() {
    echo "========================================"
    echo "    $PLUGIN_NAME v$PLUGIN_VERSION"
    echo "========================================"
    echo "Descrição: $PLUGIN_DESCRIPTION"
    echo "Autor: $PLUGIN_AUTHOR"
    echo "Categoria: $PLUGIN_CATEGORY"
    echo "Status: $([ "$plugin_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "API Version: $PLUGIN_API_VERSION"
    echo "Licença: $PLUGIN_LICENSE"
    echo ""
    echo "Dependências: ${PLUGIN_DEPENDENCIES:-Nenhuma}"
    echo "Hooks: $PLUGIN_HOOKS"
    echo ""
    echo "Arquivos:"
    echo "  - Config: $PLUGIN_CONFIG_FILE"
    echo "  - State: $PLUGIN_STATE_FILE"
    echo "  - Log: $PLUGIN_LOG_FILE"
    echo ""
}

# Health check detalhado
plugin_health_check() {
    local issues=0
    
    # Verificar inicialização
    if [ "$plugin_initialized" != true ]; then
        ((issues++))
    fi
    
    # Verificar arquivos essenciais
    if [ ! -d "$PLUGIN_DATA_DIR" ]; then
        ((issues++))
    fi
    
    # Verificar dependências
    if ! plugin_validate_dependencies >/dev/null 2>&1; then
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $issues
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init") plugin_init ;;
        "cleanup") plugin_cleanup ;;
        "configure") plugin_configure ;;
        "status") plugin_status ;;
        "health_check") plugin_health_check ;;
        "api") plugin_api_call "$2" "${@:3}" ;;
        "hook_"*) 
            local hook_name="${action#hook_}"
            local hook_function="hook_$(echo "$hook_name" | tr '.' '_')"
            if declare -f "$hook_function" >/dev/null; then
                "$hook_function" "$2"
            fi
            ;;
        *)
            echo "Advanced Plugin Commands:"
            echo "  init           - Inicializar plugin"
            echo "  cleanup        - Limpar recursos"
            echo "  configure      - Configurar plugin"
            echo "  status         - Status detalhado"
            echo "  health_check   - Verificar saúde"
            echo "  api <method>   - Chamar método da API"
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
EOF

    chmod +x "$template_dir/advanced-plugin.sh"
    
    log_info "[PluginSystem] Templates de plugin criados em $template_dir"
}

# Carregar configuração
plugin_system_load_config() {
    if [ -f "$PLUGIN_CONFIG" ]; then
        source "$PLUGIN_CONFIG" 2>/dev/null || {
            log_error "[PluginSystem] Erro ao carregar configuração"
            return 1
        }
        log_info "[PluginSystem] Configuração carregada"
    else
        log_warn "[PluginSystem] Configuração não encontrada, usando valores padrão"
    fi
}

# Registrar hooks no event system
plugin_system_register_hooks() {
    if command -v register_event_handler >/dev/null 2>&1; then
        for hook in "${available_hooks[@]}"; do
            register_event_handler "$hook" "plugin_system_execute_hooks"
        done
        log_info "[PluginSystem] Hooks registrados no event system"
    else
        log_warn "[PluginSystem] Event system não disponível"
    fi
}

# Descobrir plugins automaticamente
plugin_system_discover_plugins() {
    log_info "[PluginSystem] Descobrindo plugins..."
    
    local discovered_count=0
    
    # Descobrir em diretórios configurados
    if [ -n "${PLUGIN_DIRECTORIES[*]}" ]; then
        for plugin_dir in "${PLUGIN_DIRECTORIES[@]}"; do
            local full_path="$PROJECT_ROOT/$plugin_dir"
            if [ -d "$full_path" ]; then
                plugin_system_scan_directory "$full_path"
                ((discovered_count += $?))
            fi
        done
    fi
    
    # Descoberta automática no diretório principal
    if [ "$AUTO_DISCOVER_PLUGINS" = true ]; then
        plugin_system_scan_directory "$PLUGINS_DIR"
        ((discovered_count += $?))
    fi
    
    log_info "[PluginSystem] $discovered_count plugin(s) descoberto(s)"
    
    # Carregar plugins habilitados
    if [ "$LOAD_PLUGINS_ON_STARTUP" = true ]; then
        plugin_system_load_enabled_plugins
    fi
}

# Escanear diretório por plugins
plugin_system_scan_directory() {
    local directory="$1"
    local found_count=0
    
    # Buscar arquivos .sh que sejam plugins
    while IFS= read -r -d '' plugin_file; do
        if plugin_system_validate_plugin_file "$plugin_file"; then
            local plugin_name
            plugin_name="$(plugin_system_extract_plugin_name "$plugin_file")"
            
            if [ -n "$plugin_name" ]; then
                plugin_system_register_plugin "$plugin_name" "$plugin_file"
                ((found_count++))
            fi
        fi
    done < <(find "$directory" -name "*.sh" -type f -print0 2>/dev/null)
    
    return $found_count
}

# Validar arquivo de plugin
plugin_system_validate_plugin_file() {
    local plugin_file="$1"
    
    # Verificar se é executável
    if [ ! -x "$plugin_file" ]; then
        return 1
    fi
    
    # Verificar se contém metadados obrigatórios
    if ! grep -q "PLUGIN_NAME=" "$plugin_file" 2>/dev/null; then
        return 1
    fi
    
    if ! grep -q "PLUGIN_VERSION=" "$plugin_file" 2>/dev/null; then
        return 1
    fi
    
    # Verificação de segurança se habilitada
    if [ "$ENABLE_PLUGIN_SECURITY" = true ]; then
        if ! plugin_system_security_check "$plugin_file"; then
            log_warn "[PluginSystem] Plugin falhou na verificação de segurança: $plugin_file"
            return 1
        fi
    fi
    
    return 0
}

# Extrair nome do plugin do arquivo
plugin_system_extract_plugin_name() {
    local plugin_file="$1"
    
    # Extrair PLUGIN_NAME do arquivo
    local plugin_name
    plugin_name="$(grep "^PLUGIN_NAME=" "$plugin_file" | head -n1 | cut -d'=' -f2 | tr -d '"'"'")"
    
    echo "$plugin_name"
}

# Registrar plugin descoberto
plugin_system_register_plugin() {
    local plugin_name="$1"
    local plugin_file="$2"
    
    # Extrair metadados
    local metadata
    metadata="$(plugin_system_extract_metadata "$plugin_file")"
    
    # Armazenar informações
    loaded_plugins["$plugin_name"]="$plugin_file"
    plugin_metadata["$plugin_name"]="$metadata"
    
    # Processar hooks
    local hooks
    hooks="$(echo "$metadata" | grep "hooks:" | cut -d':' -f2 | tr -d ' ')"
    if [ -n "$hooks" ]; then
        plugin_hooks["$plugin_name"]="$hooks"
    fi
    
    log_info "[PluginSystem] Plugin registrado: $plugin_name"
}

# Extrair metadados do plugin
plugin_system_extract_metadata() {
    local plugin_file="$1"
    
    # Extrair todas as variáveis PLUGIN_*
    local name version description author category dependencies hooks
    
    name="$(grep "^PLUGIN_NAME=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    version="$(grep "^PLUGIN_VERSION=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    description="$(grep "^PLUGIN_DESCRIPTION=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    author="$(grep "^PLUGIN_AUTHOR=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    category="$(grep "^PLUGIN_CATEGORY=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    dependencies="$(grep "^PLUGIN_DEPENDENCIES=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    hooks="$(grep "^PLUGIN_HOOKS=" "$plugin_file" | cut -d'=' -f2 | tr -d '"'"'")"
    
    # Retornar metadados formatados
    cat << EOF
name:$name
version:$version
description:$description
author:$author
category:$category
dependencies:$dependencies
hooks:$hooks
file:$plugin_file
EOF
}

# Carregar plugins habilitados
plugin_system_load_enabled_plugins() {
    log_info "[PluginSystem] Carregando plugins habilitados..."
    
    local loaded_count=0
    
    # Carregar plugins da configuração
    if [ -n "${ENABLED_PLUGINS[*]}" ]; then
        for plugin_name in "${ENABLED_PLUGINS[@]}"; do
            if plugin_system_load_plugin "$plugin_name"; then
                ((loaded_count++))
            fi
        done
    fi
    
    log_info "[PluginSystem] $loaded_count plugin(s) carregado(s)"
}

# Carregar plugin específico
plugin_system_load_plugin() {
    local plugin_name="$1"
    
    if [ -z "$plugin_name" ]; then
        log_error "[PluginSystem] Nome do plugin é obrigatório"
        return 1
    fi
    
    local plugin_file="${loaded_plugins[$plugin_name]}"
    
    if [ -z "$plugin_file" ]; then
        log_error "[PluginSystem] Plugin não encontrado: $plugin_name"
        return 1
    fi
    
    if [ ! -f "$plugin_file" ]; then
        log_error "[PluginSystem] Arquivo do plugin não encontrado: $plugin_file"
        return 1
    fi
    
    log_info "[PluginSystem] Carregando plugin: $plugin_name"
    
    # Verificar dependências
    local dependencies
    dependencies="$(echo "${plugin_metadata[$plugin_name]}" | grep "dependencies:" | cut -d':' -f2)"
    
    if [ -n "$dependencies" ] && [ "$dependencies" != "" ]; then
        IFS=',' read -ra deps <<< "$dependencies"
        for dep in "${deps[@]}"; do
            dep="$(echo "$dep" | xargs)"  # trim whitespace
            if ! plugin_system_is_plugin_loaded "$dep"; then
                if ! plugin_system_load_plugin "$dep"; then
                    log_error "[PluginSystem] Falha ao carregar dependência: $dep"
                    return 1
                fi
            fi
        done
    fi
    
    # Executar inicialização do plugin
    local init_output
    if init_output="$(timeout "${PLUGIN_LOAD_TIMEOUT:-30}" bash "$plugin_file" init 2>&1)"; then
        plugin_security_status["$plugin_name"]="loaded"
        log_info "[PluginSystem] Plugin carregado com sucesso: $plugin_name"
        
        # Emitir evento
        if command -v emit_event >/dev/null 2>&1; then
            emit_event "plugin.loaded" "{\"plugin\":\"$plugin_name\"}"
        fi
        
        return 0
    else
        log_error "[PluginSystem] Falha ao inicializar plugin $plugin_name: $init_output"
        plugin_security_status["$plugin_name"]="failed"
        return 1
    fi
}

# Verificar se plugin está carregado
plugin_system_is_plugin_loaded() {
    local plugin_name="$1"
    [ "${plugin_security_status[$plugin_name]}" = "loaded" ]
}

# Descarregar plugin
plugin_system_unload_plugin() {
    local plugin_name="$1"
    
    if [ -z "$plugin_name" ]; then
        log_error "[PluginSystem] Nome do plugin é obrigatório"
        return 1
    fi
    
    local plugin_file="${loaded_plugins[$plugin_name]}"
    
    if [ -z "$plugin_file" ]; then
        log_error "[PluginSystem] Plugin não encontrado: $plugin_name"
        return 1
    fi
    
    log_info "[PluginSystem] Descarregando plugin: $plugin_name"
    
    # Executar limpeza do plugin
    bash "$plugin_file" cleanup 2>/dev/null || true
    
    # Remover do status
    plugin_security_status["$plugin_name"]="unloaded"
    
    # Emitir evento
    if command -v emit_event >/dev/null 2>&1; then
        emit_event "plugin.unloaded" "{\"plugin\":\"$plugin_name\"}"
    fi
    
    log_info "[PluginSystem] Plugin descarregado: $plugin_name"
    return 0
}

# Executar hooks dos plugins
plugin_system_execute_hooks() {
    local hook_name="$1"
    local event_data="$2"
    
    # Log se habilitado
    if [ "$LOG_HOOK_EXECUTION" = true ]; then
        log_info "[PluginSystem] Executando hooks para: $hook_name"
    fi
    
    local executed_count=0
    
    for plugin_name in "${!plugin_hooks[@]}"; do
        local plugin_hooks_list="${plugin_hooks[$plugin_name]}"
        
        # Verificar se plugin tem hook para este evento
        if [[ ",$plugin_hooks_list," == *",$hook_name,"* ]]; then
            local plugin_file="${loaded_plugins[$plugin_name]}"
            
            # Verificar se plugin está carregado
            if [ "${plugin_security_status[$plugin_name]}" = "loaded" ]; then
                # Executar hook do plugin
                local hook_action="hook_$(echo "$hook_name" | tr '.' '_')"
                
                if timeout 10 bash "$plugin_file" "$hook_action" "$event_data" 2>/dev/null; then
                    ((executed_count++))
                    
                    if [ "$LOG_HOOK_EXECUTION" = true ]; then
                        log_info "[PluginSystem] Hook executado: $plugin_name.$hook_name"
                    fi
                else
                    log_warn "[PluginSystem] Falha ao executar hook: $plugin_name.$hook_name"
                fi
            fi
        fi
    done
    
    if [ "$LOG_HOOK_EXECUTION" = true ] && [ $executed_count -gt 0 ]; then
        log_info "[PluginSystem] $executed_count hook(s) executado(s) para: $hook_name"
    fi
}

# Verificação de segurança do plugin
plugin_system_security_check() {
    local plugin_file="$1"
    
    # Verificações básicas de segurança
    
    # 1. Verificar comandos perigosos
    local dangerous_commands=(
        "rm -rf /"
        "format"
        "dd if="
        ":(){ :|:& };:"
        "curl.*|.*sh"
        "wget.*|.*sh"
    )
    
    for cmd in "${dangerous_commands[@]}"; do
        if grep -q "$cmd" "$plugin_file" 2>/dev/null; then
            log_warn "[PluginSystem] Comando perigoso detectado no plugin: $cmd"
            return 1
        fi
    done
    
    # 2. Verificar acesso a arquivos sensíveis
    local sensitive_paths=(
        "/etc/passwd"
        "/etc/shadow"
        "/root/"
        "~/.ssh/"
    )
    
    for path in "${sensitive_paths[@]}"; do
        if grep -q "$path" "$plugin_file" 2>/dev/null; then
            log_warn "[PluginSystem] Acesso a caminho sensível detectado: $path"
            return 1
        fi
    done
    
    # 3. Verificar conexões de rede suspeitas
    if grep -E "(nc|netcat|telnet).*-e" "$plugin_file" 2>/dev/null; then
        log_warn "[PluginSystem] Conexão de rede suspeita detectada"
        return 1
    fi
    
    return 0
}

# Listar plugins disponíveis
plugin_system_list_plugins() {
    echo "=================================="
    echo "        PLUGINS DISPONÍVEIS"
    echo "=================================="
    
    if [ ${#loaded_plugins[@]} -eq 0 ]; then
        echo "Nenhum plugin descoberto"
        return 0
    fi
    
    for plugin_name in "${!loaded_plugins[@]}"; do
        local metadata="${plugin_metadata[$plugin_name]}"
        local status="${plugin_security_status[$plugin_name]:-discovered}"
        local version description category
        
        version="$(echo "$metadata" | grep "version:" | cut -d':' -f2)"
        description="$(echo "$metadata" | grep "description:" | cut -d':' -f2)"
        category="$(echo "$metadata" | grep "category:" | cut -d':' -f2)"
        
        local status_icon="❓"
        case "$status" in
            "loaded") status_icon="✅" ;;
            "failed") status_icon="❌" ;;
            "unloaded") status_icon="⏸️" ;;
            "discovered") status_icon="🔍" ;;
        esac
        
        echo ""
        echo "$status_icon $plugin_name v$version ($status)"
        echo "   📝 $description"
        echo "   📂 $category"
        
        # Mostrar hooks se existirem
        local hooks="${plugin_hooks[$plugin_name]}"
        if [ -n "$hooks" ]; then
            echo "   🔗 Hooks: $hooks"
        fi
    done
    
    echo ""
}

# Status do Plugin System
plugin_system_status() {
    echo "=================================="
    echo "     PLUGIN SYSTEM STATUS"
    echo "=================================="
    echo ""
    
    echo "🔧 Sistema:"
    echo "  - Status: $([ "$is_initialized" = true ] && echo "Inicializado" || echo "Não inicializado")"
    echo "  - Segurança: $([ "$ENABLE_PLUGIN_SECURITY" = true ] && echo "Habilitada" || echo "Desabilitada")"
    echo "  - Descoberta automática: $([ "$AUTO_DISCOVER_PLUGINS" = true ] && echo "Habilitada" || echo "Desabilitada")"
    echo ""
    
    # Estatísticas
    local total_plugins=${#loaded_plugins[@]}
    local loaded_plugins_count=0
    local failed_plugins_count=0
    
    for plugin_name in "${!plugin_security_status[@]}"; do
        case "${plugin_security_status[$plugin_name]}" in
            "loaded") ((loaded_plugins_count++)) ;;
            "failed") ((failed_plugins_count++)) ;;
        esac
    done
    
    echo "📊 Estatísticas:"
    echo "  - Total descoberto: $total_plugins"
    echo "  - Carregados: $loaded_plugins_count"
    echo "  - Falharam: $failed_plugins_count"
    echo "  - Hooks disponíveis: ${#available_hooks[@]}"
    echo ""
    
    # Diretórios
    echo "📁 Diretórios:"
    echo "  - Plugins: $PLUGINS_DIR"
    echo "  - Dados: $PLUGIN_DATA_DIR"
    echo "  - Configuração: $PLUGIN_CONFIG"
    echo ""
}

# Health check do sistema
plugin_system_health_check() {
    local health_issues=0
    
    # Verificar estrutura
    if [ ! -d "$PLUGINS_DIR" ]; then
        ((health_issues++))
    fi
    
    if [ ! -d "$PLUGIN_DATA_DIR" ]; then
        ((health_issues++))
    fi
    
    # Verificar plugins carregados
    for plugin_name in "${!plugin_security_status[@]}"; do
        if [ "${plugin_security_status[$plugin_name]}" = "failed" ]; then
            ((health_issues++))
        fi
    done
    
    if [ $health_issues -eq 0 ]; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
    
    return $health_issues
}

# Função principal
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            plugin_system_init
            ;;
        "list")
            plugin_system_list_plugins
            ;;
        "load")
            plugin_system_load_plugin "$2"
            ;;
        "unload")
            plugin_system_unload_plugin "$2"
            ;;
        "reload")
            plugin_system_unload_plugin "$2" && plugin_system_load_plugin "$2"
            ;;
        "status")
            plugin_system_status
            ;;
        "discover")
            plugin_system_discover_plugins
            ;;
        "security-check")
            plugin_system_security_check "$2"
            ;;
        "health_check")
            plugin_system_health_check
            ;;
        "help"|"-h"|"--help")
            echo "Plugin System Commands:"
            echo "  init                    - Inicializar sistema de plugins"
            echo "  list                    - Listar plugins disponíveis"
            echo "  load <plugin>           - Carregar plugin específico"
            echo "  unload <plugin>         - Descarregar plugin"
            echo "  reload <plugin>         - Recarregar plugin"
            echo "  status                  - Status do sistema"
            echo "  discover                - Descobrir novos plugins"
            echo "  security-check <file>   - Verificar segurança do plugin"
            echo "  health_check            - Verificar saúde do sistema"
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