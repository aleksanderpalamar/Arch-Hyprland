#!/bin/bash

# Component Registry - Sistema de registro e gerenciamento de componentes
# Centraliza o registro, inicialização e coordenação entre componentes

source "$(dirname "${BASH_SOURCE[0]}")/../core/event-system.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../components/interface.sh"

class ComponentRegistry {
    private -A components=()
    private -A component_instances=()
    private -A component_dependencies=()
    private -A component_states=()
    private -A initialization_order=()
    private registry_config="/tmp/hypr_components.registry"
    private auto_start=true
    private initialized=false
    
    # Interface Implementation
    public init() {
        log_info "[ComponentRegistry] Inicializando Component Registry..."
        
        # Criar arquivo de registro temporário
        echo "# Hyprland Component Registry - $(date)" > "$registry_config"
        
        # Registrar eventos do sistema
        register_event_handler "component.health.check" "_handle_health_check"
        register_event_handler "component.failure" "_handle_component_failure"
        register_event_handler "system.shutdown" "_handle_system_shutdown"
        
        # Descobrir componentes automaticamente
        _discover_components
        
        initialized=true
        emit_event "component.registry.initialized" "{\"status\": \"ready\"}"
        log_info "[ComponentRegistry] Component Registry inicializado com sucesso"
        return 0
    }
    
    public validate() {
        if [ "$initialized" != "true" ]; then
            log_error "[ComponentRegistry] Tentativa de validar registry não inicializado"
            return 1
        fi
        
        log_info "[ComponentRegistry] Validando componentes registrados..."
        local errors=0
        
        for component_name in "${!components[@]}"; do
            local component_path="${components[$component_name]}"
            
            if [ ! -f "$component_path" ]; then
                log_error "[ComponentRegistry] Componente não encontrado: $component_path"
                ((errors++))
                continue
            fi
            
            # Validar interface do componente
            if ! _validate_component_interface "$component_path"; then
                log_error "[ComponentRegistry] Interface inválida: $component_name"
                ((errors++))
            fi
        done
        
        if [ $errors -gt 0 ]; then
            log_error "[ComponentRegistry] $errors componentes falharam na validação"
            return 1
        fi
        
        log_info "[ComponentRegistry] Todos os componentes validados com sucesso"
        return 0
    }
    
    public apply_theme() {
        local theme_name="$1"
        
        if [ -z "$theme_name" ]; then
            log_error "[ComponentRegistry] Nome do tema não fornecido"
            return 1
        fi
        
        log_info "[ComponentRegistry] Aplicando tema '$theme_name' aos componentes..."
        
        # Aplicar tema em ordem de prioridade
        for component_name in "${!components[@]}"; do
            local state="${component_states[$component_name]}"
            
            if [ "$state" = "running" ]; then
                log_info "[ComponentRegistry] Aplicando tema em: $component_name"
                
                local instance="${component_instances[$component_name]}"
                if [ -n "$instance" ]; then
                    if ! "$instance" apply_theme "$theme_name"; then
                        log_warn "[ComponentRegistry] Falha ao aplicar tema em $component_name"
                    fi
                fi
            fi
        done
        
        emit_event "theme.applied.all" "{\"theme\": \"$theme_name\"}"
        log_info "[ComponentRegistry] Tema aplicado em todos os componentes"
        return 0
    }
    
    public cleanup() {
        log_info "[ComponentRegistry] Executando limpeza do Component Registry..."
        
        # Parar todos os componentes em ordem reversa
        _stop_all_components
        
        # Limpar registros
        components=()
        component_instances=()
        component_dependencies=()
        component_states=()
        
        # Remover arquivo de registro
        [ -f "$registry_config" ] && rm -f "$registry_config"
        
        initialized=false
        emit_event "component.registry.cleanup" "{\"status\": \"completed\"}"
        log_info "[ComponentRegistry] Limpeza concluída"
        return 0
    }
    
    public health_check() {
        local status="healthy"
        local issues=()
        local component_count=0
        local healthy_count=0
        
        # Verificar inicialização
        if [ "$initialized" != "true" ]; then
            status="unhealthy"
            issues+=("Registry não inicializado")
        fi
        
        # Verificar estado dos componentes
        for component_name in "${!components[@]}"; do
            ((component_count++))
            local state="${component_states[$component_name]}"
            local instance="${component_instances[$component_name]}"
            
            case "$state" in
                "running")
                    if [ -n "$instance" ]; then
                        local component_health="$("$instance" health_check 2>/dev/null || echo "unhealthy")"
                        if [ "$component_health" = "healthy" ]; then
                            ((healthy_count++))
                        else
                            issues+=("Componente $component_name: $component_health")
                            if [ "$status" = "healthy" ]; then
                                status="degraded"
                            fi
                        fi
                    else
                        issues+=("Componente $component_name sem instância")
                        status="degraded"
                    fi
                    ;;
                "failed")
                    issues+=("Componente $component_name falhou")
                    status="degraded"
                    ;;
                "stopped")
                    issues+=("Componente $component_name parado")
                    if [ "$status" = "healthy" ]; then
                        status="degraded"
                    fi
                    ;;
            esac
        done
        
        # Determinar status geral
        if [ $component_count -eq 0 ]; then
            status="unhealthy"
            issues+=("Nenhum componente registrado")
        elif [ $healthy_count -eq 0 ] && [ $component_count -gt 0 ]; then
            status="unhealthy"
        fi
        
        # Log do status
        case "$status" in
            "healthy")
                log_info "[ComponentRegistry] Health check: $healthy_count/$component_count componentes saudáveis"
                ;;
            "degraded")
                log_warn "[ComponentRegistry] Health check: Sistema degradado - ${issues[*]}"
                ;;
            "unhealthy")
                log_error "[ComponentRegistry] Health check: Sistema não saudável - ${issues[*]}"
                ;;
        esac
        
        echo "$status"
        return $([ "$status" = "healthy" ] && echo 0 || echo 1)
    }
    
    # Métodos Públicos do Component Registry
    public register_component() {
        local component_name="$1"
        local component_path="$2"
        local dependencies="$3"
        local auto_start="${4:-true}"
        
        if [ -z "$component_name" ] || [ -z "$component_path" ]; then
            log_error "[ComponentRegistry] Parâmetros obrigatórios faltando para registro"
            return 1
        fi
        
        if [ ! -f "$component_path" ]; then
            log_error "[ComponentRegistry] Arquivo do componente não encontrado: $component_path"
            return 1
        fi
        
        # Validar interface antes de registrar
        if ! _validate_component_interface "$component_path"; then
            log_error "[ComponentRegistry] Interface do componente inválida: $component_name"
            return 1
        fi
        
        components["$component_name"]="$component_path"
        component_states["$component_name"]="registered"
        
        if [ -n "$dependencies" ]; then
            component_dependencies["$component_name"]="$dependencies"
        fi
        
        # Registrar no arquivo de configuração
        echo "component[$component_name]=$component_path" >> "$registry_config"
        
        log_info "[ComponentRegistry] Componente registrado: $component_name"
        emit_event "component.registered" "{\"name\": \"$component_name\", \"path\": \"$component_path\"}"
        
        # Auto-iniciar se habilitado
        if [ "$auto_start" = "true" ] && [ "$auto_start" = "true" ]; then
            start_component "$component_name"
        fi
        
        return 0
    }
    
    public unregister_component() {
        local component_name="$1"
        
        if [ -z "$component_name" ]; then
            log_error "[ComponentRegistry] Nome do componente não fornecido"
            return 1
        fi
        
        # Parar componente se estiver rodando
        if [ "${component_states[$component_name]}" = "running" ]; then
            stop_component "$component_name"
        fi
        
        # Remover registros
        unset components["$component_name"]
        unset component_instances["$component_name"]
        unset component_dependencies["$component_name"]
        unset component_states["$component_name"]
        
        log_info "[ComponentRegistry] Componente removido: $component_name"
        emit_event "component.unregistered" "{\"name\": \"$component_name\"}"
        return 0
    }
    
    public start_component() {
        local component_name="$1"
        
        if [ -z "$component_name" ]; then
            log_error "[ComponentRegistry] Nome do componente não fornecido"
            return 1
        fi
        
        local component_path="${components[$component_name]}"
        if [ -z "$component_path" ]; then
            log_error "[ComponentRegistry] Componente não registrado: $component_name"
            return 1
        fi
        
        local current_state="${component_states[$component_name]}"
        if [ "$current_state" = "running" ]; then
            log_warn "[ComponentRegistry] Componente já está rodando: $component_name"
            return 0
        fi
        
        log_info "[ComponentRegistry] Iniciando componente: $component_name"
        
        # Verificar dependências
        local dependencies="${component_dependencies[$component_name]}"
        if [ -n "$dependencies" ]; then
            if ! _check_dependencies "$dependencies"; then
                log_error "[ComponentRegistry] Dependências não satisfeitas para $component_name"
                return 1
            fi
        fi
        
        # Carregar e instanciar componente
        if ! source "$component_path"; then
            log_error "[ComponentRegistry] Falha ao carregar componente: $component_path"
            component_states["$component_name"]="failed"
            return 1
        fi
        
        # Criar instância
        local class_name="$(basename "$component_path" .sh)"
        class_name="${class_name^}Component"  # Capitalizar primeira letra
        
        local instance="$(new $class_name 2>/dev/null)"
        if [ -z "$instance" ]; then
            log_error "[ComponentRegistry] Falha ao instanciar $class_name"
            component_states["$component_name"]="failed"
            return 1
        fi
        
        # Inicializar componente
        if ! "$instance" init; then
            log_error "[ComponentRegistry] Falha na inicialização de $component_name"
            component_states["$component_name"]="failed"
            return 1
        fi
        
        # Salvar instância e estado
        component_instances["$component_name"]="$instance"
        component_states["$component_name"]="running"
        
        emit_event "component.started" "{\"name\": \"$component_name\"}"
        log_info "[ComponentRegistry] Componente $component_name iniciado com sucesso"
        return 0
    }
    
    public stop_component() {
        local component_name="$1"
        
        if [ -z "$component_name" ]; then
            log_error "[ComponentRegistry] Nome do componente não fornecido"
            return 1
        fi
        
        local current_state="${component_states[$component_name]}"
        if [ "$current_state" != "running" ]; then
            log_warn "[ComponentRegistry] Componente não está rodando: $component_name"
            return 0
        fi
        
        log_info "[ComponentRegistry] Parando componente: $component_name"
        
        local instance="${component_instances[$component_name]}"
        if [ -n "$instance" ]; then
            # Executar cleanup do componente
            if ! "$instance" cleanup; then
                log_warn "[ComponentRegistry] Falha no cleanup de $component_name"
            fi
        fi
        
        # Atualizar estado
        component_states["$component_name"]="stopped"
        unset component_instances["$component_name"]
        
        emit_event "component.stopped" "{\"name\": \"$component_name\"}"
        log_info "[ComponentRegistry] Componente $component_name parado"
        return 0
    }
    
    public restart_component() {
        local component_name="$1"
        
        if [ -z "$component_name" ]; then
            log_error "[ComponentRegistry] Nome do componente não fornecido"
            return 1
        fi
        
        log_info "[ComponentRegistry] Reiniciando componente: $component_name"
        
        if ! stop_component "$component_name"; then
            log_error "[ComponentRegistry] Falha ao parar componente para restart"
            return 1
        fi
        
        sleep 1  # Pequena pausa para evitar conflitos
        
        if ! start_component "$component_name"; then
            log_error "[ComponentRegistry] Falha ao reiniciar componente"
            return 1
        fi
        
        emit_event "component.restarted" "{\"name\": \"$component_name\"}"
        log_info "[ComponentRegistry] Componente $component_name reiniciado com sucesso"
        return 0
    }
    
    public list_components() {
        if [ ${#components[@]} -eq 0 ]; then
            echo "Nenhum componente registrado"
            return 0
        fi
        
        echo "Componentes registrados:"
        for component_name in "${!components[@]}"; do
            local component_path="${components[$component_name]}"
            local state="${component_states[$component_name]:-"unknown"}"
            local dependencies="${component_dependencies[$component_name]:-"N/A"}"
            
            echo "  $component_name:"
            echo "    Caminho: $component_path"
            echo "    Estado: $state"
            echo "    Dependências: $dependencies"
        done
        
        return 0
    }
    
    public get_component_status() {
        local component_name="$1"
        
        if [ -z "$component_name" ]; then
            log_error "[ComponentRegistry] Nome do componente não fornecido"
            return 1
        fi
        
        if [ -z "${components[$component_name]}" ]; then
            echo "not_registered"
            return 1
        fi
        
        echo "${component_states[$component_name]:-"unknown"}"
        return 0
    }
    
    public start_all_components() {
        log_info "[ComponentRegistry] Iniciando todos os componentes..."
        
        # Ordenar por dependências
        local start_order=()
        _calculate_start_order start_order
        
        local failed_count=0
        for component_name in "${start_order[@]}"; do
            if ! start_component "$component_name"; then
                ((failed_count++))
                log_error "[ComponentRegistry] Falha ao iniciar $component_name"
            fi
        done
        
        if [ $failed_count -eq 0 ]; then
            log_info "[ComponentRegistry] Todos os componentes iniciados com sucesso"
        else
            log_warn "[ComponentRegistry] $failed_count componentes falharam ao iniciar"
        fi
        
        emit_event "components.started.all" "{\"failed_count\": $failed_count}"
        return $([ $failed_count -eq 0 ] && echo 0 || echo 1)
    }
    
    public stop_all_components() {
        log_info "[ComponentRegistry] Parando todos os componentes..."
        
        _stop_all_components
        
        emit_event "components.stopped.all" "{\"status\": \"completed\"}"
        log_info "[ComponentRegistry] Todos os componentes parados"
        return 0
    }
    
    # Métodos Privados
    private _discover_components() {
        local components_dir="$(dirname "${BASH_SOURCE[0]}")/../components"
        
        if [ ! -d "$components_dir" ]; then
            log_warn "[ComponentRegistry] Diretório de componentes não encontrado: $components_dir"
            return 1
        fi
        
        log_info "[ComponentRegistry] Descobrindo componentes em: $components_dir"
        
        for component_dir in "$components_dir"/*; do
            if [ -d "$component_dir" ]; then
                local component_name="$(basename "$component_dir")"
                local component_file="$component_dir/${component_name}-component.sh"
                
                if [ -f "$component_file" ]; then
                    log_info "[ComponentRegistry] Componente descoberto: $component_name"
                    register_component "$component_name" "$component_file" "" "true"
                fi
            fi
        done
        
        log_info "[ComponentRegistry] Descoberta de componentes concluída"
    }
    
    private _validate_component_interface() {
        local component_path="$1"
        
        # Verificar se o componente implementa a interface obrigatória
        local required_methods=("init" "validate" "apply_theme" "cleanup" "health_check")
        
        for method in "${required_methods[@]}"; do
            if ! grep -q "public $method()" "$component_path"; then
                log_error "[ComponentRegistry] Método obrigatório não encontrado: $method"
                return 1
            fi
        done
        
        return 0
    }
    
    private _check_dependencies() {
        local dependencies="$1"
        
        # Separar dependências por vírgula
        IFS=',' read -ra dep_array <<< "$dependencies"
        
        for dep in "${dep_array[@]}"; do
            dep="$(echo "$dep" | xargs)"  # Remover espaços
            
            local dep_state="${component_states[$dep]}"
            if [ "$dep_state" != "running" ]; then
                log_error "[ComponentRegistry] Dependência não satisfeita: $dep (estado: $dep_state)"
                return 1
            fi
        done
        
        return 0
    }
    
    private _calculate_start_order() {
        local -n order_ref=$1
        
        # Implementação simples de ordenação topológica
        # Para componentes sem dependências primeiro
        for component_name in "${!components[@]}"; do
            local dependencies="${component_dependencies[$component_name]}"
            
            if [ -z "$dependencies" ]; then
                order_ref+=("$component_name")
            fi
        done
        
        # Depois componentes com dependências
        for component_name in "${!components[@]}"; do
            local dependencies="${component_dependencies[$component_name]}"
            
            if [ -n "$dependencies" ]; then
                order_ref+=("$component_name")
            fi
        done
    }
    
    private _stop_all_components() {
        # Parar em ordem reversa para respeitar dependências
        local stop_order=()
        _calculate_start_order stop_order
        
        # Reverter array
        local reversed=()
        for ((i=${#stop_order[@]}-1; i>=0; i--)); do
            reversed+=("${stop_order[$i]}")
        done
        
        for component_name in "${reversed[@]}"; do
            local state="${component_states[$component_name]}"
            if [ "$state" = "running" ]; then
                stop_component "$component_name"
            fi
        done
    }
    
    private _handle_health_check() {
        local event_data="$1"
        
        log_info "[ComponentRegistry] Executando health check periódico..."
        
        for component_name in "${!components[@]}"; do
            local state="${component_states[$component_name]}"
            local instance="${component_instances[$component_name]}"
            
            if [ "$state" = "running" ] && [ -n "$instance" ]; then
                local health="$("$instance" health_check 2>/dev/null || echo "unhealthy")"
                
                if [ "$health" != "healthy" ]; then
                    log_warn "[ComponentRegistry] Componente não saudável: $component_name ($health)"
                    emit_event "component.unhealthy" "{\"name\": \"$component_name\", \"health\": \"$health\"}"
                fi
            fi
        done
    }
    
    private _handle_component_failure() {
        local event_data="$1"
        local component_name="$(echo "$event_data" | grep -o '"name": "[^"]*"' | cut -d'"' -f4)"
        
        if [ -n "$component_name" ]; then
            log_error "[ComponentRegistry] Componente falhou: $component_name"
            component_states["$component_name"]="failed"
            
            # Tentar reiniciar automaticamente
            log_info "[ComponentRegistry] Tentando reiniciar $component_name automaticamente..."
            if restart_component "$component_name"; then
                log_info "[ComponentRegistry] Componente $component_name recuperado"
            else
                log_error "[ComponentRegistry] Falha na recuperação automática de $component_name"
            fi
        fi
    }
    
    private _handle_system_shutdown() {
        log_info "[ComponentRegistry] Sistema sendo desligado, parando componentes..."
        stop_all_components
    }
}

# Instanciar Component Registry global
component_registry="$(new ComponentRegistry)"