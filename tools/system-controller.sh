#!/bin/bash

# System Controller - Controlador principal do sistema modular
# Orquestra a inicialização e coordenação entre todos os serviços e componentes

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/config-manager.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../services/component-registry.sh"

class SystemController {
    private system_state="stopped"
    private startup_time=""
    private services_initialized=false
    private components_started=false
    private config_loaded=false
    private system_config="$HOME/.config/hypr/system.conf"
    private pid_file="/tmp/hypr_system.pid"
    private log_level="INFO"
    
    # Interface Implementation
    public init() {
        log_info "[SystemController] Inicializando Sistema Hyprland Modular..."
        startup_time="$(date '+%Y-%m-%d %H:%M:%S')"
        
        # Verificar se já existe uma instância rodando
        if [ -f "$pid_file" ]; then
            local existing_pid="$(cat "$pid_file")"
            if kill -0 "$existing_pid" 2>/dev/null; then
                log_error "[SystemController] Sistema já está rodando (PID: $existing_pid)"
                return 1
            else
                log_warn "[SystemController] Removendo PID file obsoleto"
                rm -f "$pid_file"
            fi
        fi
        
        # Registrar PID atual
        echo "$$" > "$pid_file"
        
        # Registrar handlers para sinais do sistema
        trap '_handle_sigterm' TERM
        trap '_handle_sigint' INT
        trap '_handle_sigusr1' USR1
        
        # Registrar eventos globais
        register_event_handler "system.shutdown" "_handle_shutdown_request"
        register_event_handler "system.restart" "_handle_restart_request"
        register_event_handler "system.reload" "_handle_reload_request"
        
        # Carregar configuração do sistema
        _load_system_config
        
        system_state="initializing"
        emit_event "system.initializing" "{\"startup_time\": \"$startup_time\"}"
        
        log_info "[SystemController] Sistema inicializado (PID: $$)"
        return 0
    }
    
    public validate() {
        log_info "[SystemController] Validando configuração do sistema..."
        
        # Validar dependências do sistema
        local missing_deps=()
        local required_commands=("hyprland" "waybar" "rofi")
        
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                missing_deps+=("$cmd")
            fi
        done
        
        if [ ${#missing_deps[@]} -gt 0 ]; then
            log_error "[SystemController] Dependências faltando: ${missing_deps[*]}"
            return 1
        fi
        
        # Validar estrutura de diretórios
        local required_dirs=("$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/rofi")
        
        for dir in "${required_dirs[@]}"; do
            if [ ! -d "$dir" ]; then
                log_warn "[SystemController] Diretório não encontrado: $dir"
            fi
        done
        
        log_info "[SystemController] Validação do sistema concluída"
        return 0
    }
    
    public apply_theme() {
        local theme_name="$1"
        
        if [ -z "$theme_name" ]; then
            log_error "[SystemController] Nome do tema não fornecido"
            return 1
        fi
        
        if [ "$system_state" != "running" ]; then
            log_error "[SystemController] Sistema deve estar rodando para aplicar tema"
            return 1
        fi
        
        log_info "[SystemController] Aplicando tema do sistema: $theme_name"
        
        # Aplicar tema através do Configuration Manager
        if [ "$config_loaded" = "true" ]; then
            if ! "$config_manager" apply_theme "$theme_name"; then
                log_error "[SystemController] Falha ao aplicar tema no Configuration Manager"
                return 1
            fi
        fi
        
        # Aplicar tema através do Component Registry
        if [ "$components_started" = "true" ]; then
            if ! "$component_registry" apply_theme "$theme_name"; then
                log_error "[SystemController] Falha ao aplicar tema nos componentes"
                return 1
            fi
        fi
        
        emit_event "system.theme.applied" "{\"theme\": \"$theme_name\"}"
        log_info "[SystemController] Tema '$theme_name' aplicado em todo o sistema"
        return 0
    }
    
    public cleanup() {
        log_info "[SystemController] Executando limpeza do sistema..."
        
        system_state="shutting_down"
        emit_event "system.shutting_down" "{\"timestamp\": \"$(date)\"}"
        
        # Parar componentes
        if [ "$components_started" = "true" ]; then
            log_info "[SystemController] Parando componentes..."
            "$component_registry" cleanup
            components_started=false
        fi
        
        # Limpar Configuration Manager
        if [ "$config_loaded" = "true" ]; then
            log_info "[SystemController] Limpando Configuration Manager..."
            "$config_manager" cleanup
            config_loaded=false
        fi
        
        # Remover PID file
        [ -f "$pid_file" ] && rm -f "$pid_file"
        
        system_state="stopped"
        emit_event "system.stopped" "{\"timestamp\": \"$(date)\"}"
        
        log_info "[SystemController] Limpeza do sistema concluída"
        return 0
    }
    
    public health_check() {
        local status="healthy"
        local issues=()
        
        # Verificar estado do sistema
        case "$system_state" in
            "running")
                # Sistema rodando normalmente
                ;;
            "initializing"|"starting")
                status="degraded"
                issues+=("Sistema ainda inicializando")
                ;;
            "shutting_down"|"stopped")
                status="unhealthy"
                issues+=("Sistema não está rodando")
                ;;
            *)
                status="unhealthy"
                issues+=("Estado do sistema desconhecido: $system_state")
                ;;
        esac
        
        # Verificar serviços críticos
        if [ "$config_loaded" = "true" ]; then
            local config_health="$("$config_manager" health_check 2>/dev/null || echo "unhealthy")"
            if [ "$config_health" != "healthy" ]; then
                status="degraded"
                issues+=("Configuration Manager: $config_health")
            fi
        else
            status="degraded"
            issues+=("Configuration Manager não carregado")
        fi
        
        if [ "$components_started" = "true" ]; then
            local registry_health="$("$component_registry" health_check 2>/dev/null || echo "unhealthy")"
            if [ "$registry_health" != "healthy" ]; then
                status="degraded"
                issues+=("Component Registry: $registry_health")
            fi
        else
            status="degraded"
            issues+=("Component Registry não iniciado")
        fi
        
        # Verificar PID file
        if [ ! -f "$pid_file" ]; then
            status="unhealthy"
            issues+=("PID file não encontrado")
        fi
        
        # Log do status
        case "$status" in
            "healthy")
                log_info "[SystemController] Health check: Sistema saudável"
                ;;
            "degraded")
                log_warn "[SystemController] Health check: Sistema degradado - ${issues[*]}"
                ;;
            "unhealthy")
                log_error "[SystemController] Health check: Sistema não saudável - ${issues[*]}"
                ;;
        esac
        
        echo "$status"
        return $([ "$status" = "healthy" ] && echo 0 || echo 1)
    }
    
    # Métodos Públicos do System Controller
    public start_system() {
        if [ "$system_state" = "running" ]; then
            log_warn "[SystemController] Sistema já está rodando"
            return 0
        fi
        
        log_info "[SystemController] Iniciando sistema Hyprland..."
        system_state="starting"
        
        # Validar sistema antes de iniciar
        if ! validate; then
            log_error "[SystemController] Falha na validação, abortando inicialização"
            system_state="failed"
            return 1
        fi
        
        # Inicializar Configuration Manager
        log_info "[SystemController] Inicializando Configuration Manager..."
        if ! "$config_manager" init; then
            log_error "[SystemController] Falha ao inicializar Configuration Manager"
            system_state="failed"
            return 1
        fi
        
        # Validar configurações
        if ! "$config_manager" validate; then
            log_error "[SystemController] Falha na validação de configurações"
            system_state="failed"
            return 1
        fi
        
        config_loaded=true
        log_info "[SystemController] Configuration Manager inicializado"
        
        # Inicializar Component Registry
        log_info "[SystemController] Inicializando Component Registry..."
        if ! "$component_registry" init; then
            log_error "[SystemController] Falha ao inicializar Component Registry"
            system_state="failed"
            return 1
        fi
        
        # Validar componentes
        if ! "$component_registry" validate; then
            log_error "[SystemController] Falha na validação de componentes"
            system_state="failed"
            return 1
        fi
        
        # Iniciar todos os componentes
        log_info "[SystemController] Iniciando componentes..."
        if ! "$component_registry" start_all_components; then
            log_warn "[SystemController] Alguns componentes falharam ao iniciar"
        fi
        
        components_started=true
        system_state="running"
        
        emit_event "system.started" "{\"startup_time\": \"$startup_time\", \"state\": \"running\"}"
        log_info "[SystemController] Sistema Hyprland iniciado com sucesso!"
        
        return 0
    }
    
    public stop_system() {
        if [ "$system_state" = "stopped" ]; then
            log_warn "[SystemController] Sistema já está parado"
            return 0
        fi
        
        log_info "[SystemController] Parando sistema Hyprland..."
        
        cleanup
        
        log_info "[SystemController] Sistema parado"
        return 0
    }
    
    public restart_system() {
        log_info "[SystemController] Reiniciando sistema Hyprland..."
        
        if ! stop_system; then
            log_error "[SystemController] Falha ao parar sistema para restart"
            return 1
        fi
        
        sleep 2  # Pausa para evitar conflitos
        
        if ! start_system; then
            log_error "[SystemController] Falha ao reiniciar sistema"
            return 1
        fi
        
        emit_event "system.restarted" "{\"timestamp\": \"$(date)\"}"
        log_info "[SystemController] Sistema reiniciado com sucesso"
        return 0
    }
    
    public reload_system() {
        log_info "[SystemController] Recarregando configurações do sistema..."
        
        if [ "$system_state" != "running" ]; then
            log_error "[SystemController] Sistema deve estar rodando para reload"
            return 1
        fi
        
        # Recarregar Configuration Manager
        if [ "$config_loaded" = "true" ]; then
            log_info "[SystemController] Recarregando configurações..."
            if ! "$config_manager" validate; then
                log_error "[SystemController] Configurações inválidas após reload"
                return 1
            fi
        fi
        
        # Recarregar componentes críticos
        if [ "$components_started" = "true" ]; then
            log_info "[SystemController] Recarregando componentes críticos..."
            
            # Lista de componentes críticos que precisam de reload
            local critical_components=("waybar" "rofi")
            
            for comp in "${critical_components[@]}"; do
                local comp_status="$("$component_registry" get_component_status "$comp")"
                if [ "$comp_status" = "running" ]; then
                    log_info "[SystemController] Recarregando $comp..."
                    "$component_registry" restart_component "$comp"
                fi
            done
        fi
        
        emit_event "system.reloaded" "{\"timestamp\": \"$(date)\"}"
        log_info "[SystemController] Sistema recarregado"
        return 0
    }
    
    public get_system_status() {
        echo "Estado do Sistema: $system_state"
        echo "Iniciado em: $startup_time"
        echo "PID: $(cat "$pid_file" 2>/dev/null || echo "N/A")"
        echo "Configuration Manager: $([ "$config_loaded" = "true" ] && echo "Carregado" || echo "Não carregado")"
        echo "Component Registry: $([ "$components_started" = "true" ] && echo "Iniciado" || echo "Não iniciado")"
        
        if [ "$components_started" = "true" ]; then
            echo ""
            echo "=== Componentes ==="
            "$component_registry" list_components
        fi
        
        if [ "$config_loaded" = "true" ]; then
            echo ""
            echo "=== Configurações ==="
            "$config_manager" list_configs
        fi
    }
    
    public run_daemon() {
        log_info "[SystemController] Iniciando em modo daemon..."
        
        # Inicializar sistema
        if ! start_system; then
            log_error "[SystemController] Falha ao iniciar sistema em modo daemon"
            exit 1
        fi
        
        # Loop principal do daemon
        log_info "[SystemController] Entrando no loop principal do daemon..."
        
        while [ "$system_state" = "running" ]; do
            # Health check periódico
            if ! health_check >/dev/null 2>&1; then
                log_warn "[SystemController] Health check falhou, verificando componentes..."
                
                # Tentar recuperar componentes falhos
                if [ "$components_started" = "true" ]; then
                    emit_event "component.health.check" "{\"timestamp\": \"$(date)\"}"
                fi
            fi
            
            # Verificar eventos pendentes
            sleep 30  # Check a cada 30 segundos
        done
        
        log_info "[SystemController] Saindo do daemon"
    }
    
    # Métodos Privados
    private _load_system_config() {
        if [ -f "$system_config" ]; then
            log_info "[SystemController] Carregando configuração do sistema: $system_config"
            source "$system_config"
        else
            log_info "[SystemController] Criando configuração padrão do sistema"
            _create_default_system_config
        fi
    }
    
    private _create_default_system_config() {
        local config_dir="$(dirname "$system_config")"
        mkdir -p "$config_dir"
        
        cat > "$system_config" << 'EOF'
# Configuração do Sistema Hyprland Modular
# Gerado automaticamente

# Configurações gerais
AUTO_START_COMPONENTS=true
AUTO_RELOAD_ON_CHANGE=true
HEALTH_CHECK_INTERVAL=30
LOG_LEVEL=INFO

# Componentes habilitados
ENABLE_WAYBAR=true
ENABLE_ROFI=true
ENABLE_WALLPAPER=true

# Configurações de tema
DEFAULT_THEME="default"
AUTO_APPLY_THEME=true

# Configurações de backup
AUTO_BACKUP=true
BACKUP_RETENTION_DAYS=7

# Configurações de monitoramento
ENABLE_HEALTH_MONITORING=true
ALERT_ON_COMPONENT_FAILURE=true
EOF
        
        log_info "[SystemController] Configuração padrão criada: $system_config"
    }
    
    private _handle_sigterm() {
        log_info "[SystemController] Recebido SIGTERM, parando sistema..."
        stop_system
        exit 0
    }
    
    private _handle_sigint() {
        log_info "[SystemController] Recebido SIGINT, parando sistema..."
        stop_system
        exit 0
    }
    
    private _handle_sigusr1() {
        log_info "[SystemController] Recebido SIGUSR1, recarregando sistema..."
        reload_system
    }
    
    private _handle_shutdown_request() {
        local event_data="$1"
        log_info "[SystemController] Solicitação de shutdown recebida"
        stop_system
    }
    
    private _handle_restart_request() {
        local event_data="$1"
        log_info "[SystemController] Solicitação de restart recebida"
        restart_system
    }
    
    private _handle_reload_request() {
        local event_data="$1"
        log_info "[SystemController] Solicitação de reload recebida"
        reload_system
    }
}

# Script principal
main() {
    local action="${1:-start}"
    local system_controller="$(new SystemController)"
    
    # Inicializar sempre primeiro
    if ! "$system_controller" init; then
        echo "Falha ao inicializar System Controller" >&2
        exit 1
    fi
    
    case "$action" in
        "start")
            "$system_controller" start_system
            ;;
        "stop")
            "$system_controller" stop_system
            ;;
        "restart")
            "$system_controller" restart_system
            ;;
        "reload")
            "$system_controller" reload_system
            ;;
        "status")
            "$system_controller" get_system_status
            ;;
        "health")
            "$system_controller" health_check
            ;;
        "daemon")
            "$system_controller" run_daemon
            ;;
        "theme")
            local theme_name="$2"
            if [ -z "$theme_name" ]; then
                echo "Uso: $0 theme <nome_do_tema>" >&2
                exit 1
            fi
            "$system_controller" apply_theme "$theme_name"
            ;;
        "help"|"-h"|"--help")
            echo "Uso: $0 <ação> [parâmetros]"
            echo ""
            echo "Ações disponíveis:"
            echo "  start     - Iniciar o sistema"
            echo "  stop      - Parar o sistema"
            echo "  restart   - Reiniciar o sistema"
            echo "  reload    - Recarregar configurações"
            echo "  status    - Mostrar status do sistema"
            echo "  health    - Verificar saúde do sistema"
            echo "  daemon    - Rodar em modo daemon"
            echo "  theme <nome> - Aplicar tema"
            echo "  help      - Mostrar esta ajuda"
            ;;
        *)
            echo "Ação desconhecida: $action" >&2
            echo "Use '$0 help' para ver as ações disponíveis" >&2
            exit 1
            ;;
    esac
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi