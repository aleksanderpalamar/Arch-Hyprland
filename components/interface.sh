#!/bin/bash

# Interface Component - Define a interface padrão para todos os componentes
# Todos os componentes devem implementar estes métodos obrigatórios

# Esta é uma interface conceitual - em bash, não há interfaces formais
# Os componentes devem implementar as seguintes funções:

# init() - Inicializar o componente
# validate() - Validar configuração e dependências
# apply_theme(theme_name) - Aplicar tema específico
# cleanup() - Limpeza e shutdown do componente
# health_check() - Verificar estado de saúde do componente

# Função para validar se um componente implementa a interface
validate_component_interface() {
    local component_file="$1"
    
    if [ ! -f "$component_file" ]; then
        echo "Arquivo do componente não encontrado: $component_file" >&2
        return 1
    fi
    
    local required_methods=("init" "validate" "apply_theme" "cleanup" "health_check")
    local missing_methods=()
    
    for method in "${required_methods[@]}"; do
        if ! grep -q "public $method()" "$component_file"; then
            missing_methods+=("$method")
        fi
    done
    
    if [ ${#missing_methods[@]} -gt 0 ]; then
        echo "Métodos obrigatórios não implementados: ${missing_methods[*]}" >&2
        return 1
    fi
    
    return 0
}

# Função para listar métodos obrigatórios
list_required_methods() {
    echo "Métodos obrigatórios da interface Component:"
    echo "  - init(): Inicializar o componente"
    echo "  - validate(): Validar configuração e dependências"
    echo "  - apply_theme(theme_name): Aplicar tema específico"
    echo "  - cleanup(): Limpeza e shutdown do componente"
    echo "  - health_check(): Verificar estado de saúde do componente"
}

# Exportar funções utilitárias
export -f validate_component_interface list_required_methods