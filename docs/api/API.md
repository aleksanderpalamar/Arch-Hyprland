# 📚 API Reference - Arch-Hyprland

Esta documentação descreve as APIs e interfaces dos componentes do sistema modular Arch-Hyprland.

## 🏗️ Core APIs

### Event System API

O Event System fornece comunicação assíncrona entre componentes.

#### Registrar Handler de Evento

```bash
register_event_handler <event_name> <handler_function>
```

**Parâmetros:**

- `event_name`: Nome do evento (ex: "wallpaper.changed")
- `handler_function`: Função que processará o evento

**Exemplo:**

```bash
handle_wallpaper_change() {
    local event_data="$1"
    echo "Wallpaper alterado: $event_data"
}

register_event_handler "wallpaper.changed" "handle_wallpaper_change"
```

#### Emitir Evento

```bash
emit_event <event_name> [event_data]
```

**Parâmetros:**

- `event_name`: Nome do evento
- `event_data`: Dados opcionais do evento (JSON recomendado)

**Exemplo:**

```bash
emit_event "theme.changed" '{"theme": "dark", "timestamp": "2025-10-24"}'
```

#### Eventos Padrão do Sistema

| Evento              | Descrição             | Dados                                   |
| ------------------- | --------------------- | --------------------------------------- |
| `system.init`       | Sistema inicializando | `{"status": "initializing"}`            |
| `system.startup`    | Sistema iniciado      | `{"startup_time": "timestamp"}`         |
| `system.shutdown`   | Sistema desligando    | `{"reason": "user_request"}`            |
| `component.loaded`  | Componente carregado  | `{"component": "name"}`                 |
| `component.failed`  | Componente falhou     | `{"component": "name", "error": "msg"}` |
| `theme.changed`     | Tema alterado         | `{"theme": "name", "colors": {...}}`    |
| `wallpaper.changed` | Wallpaper alterado    | `{"path": "/path/to/image"}`            |
| `config.changed`    | Configuração alterada | `{"config": "name", "path": "file"}`    |

### Logger API

Sistema de logging centralizado com níveis configuráveis.

#### Funções de Log

```bash
log_debug <message>    # Nível DEBUG
log_info <message>     # Nível INFO
log_warn <message>     # Nível WARNING
log_error <message>    # Nível ERROR
log_fatal <message>    # Nível FATAL
```

**Exemplo:**

```bash
log_info "Componente inicializado com sucesso"
log_error "Falha ao carregar configuração: arquivo não encontrado"
```

## 🔧 Services APIs

### Configuration Manager API

Gerencia configurações de forma centralizada com validação.

#### Registrar Configuração

```bash
config_manager register_config <name> <path> <validator> <component>
```

**Parâmetros:**

- `name`: Nome da configuração
- `path`: Caminho para o arquivo
- `validator`: Função de validação
- `component`: Componente associado

#### Validar Configuração

```bash
config_manager validate_config <config_name>
```

#### Aplicar Tema

```bash
config_manager apply_theme <config_name> <theme_name>
```

### Theme Engine API

Sistema centralizado de gerenciamento de temas.

#### Descobrir Temas

```bash
theme_engine discover
```

#### Aplicar Tema

```bash
theme_engine apply_theme <theme_name>
```

#### Registrar Componente para Temas

```bash
theme_engine register_component <component_name> <theme_function>
```

### Backup Service API

Sistema de backup com versionamento e compressão.

#### Criar Backup Completo

```bash
backup_service create_full_backup [backup_name]
```

#### Restaurar Backup

```bash
backup_service restore <backup_name>
```

#### Listar Backups

```bash
backup_service list_backups
```

### Monitor Service API

Monitoramento em tempo real de componentes.

#### Registrar Componente para Monitoramento

```bash
monitor_service register <component_name> [script_path]
```

#### Verificar Saúde de Todos os Componentes

```bash
monitor_service check
```

#### Gerar Relatório

```bash
monitor_service report
```

### Plugin System API

Sistema extensível de plugins com descoberta automática.

#### Carregar Plugin

```bash
plugin_system load <plugin_name>
```

#### Descarregar Plugin

```bash
plugin_system unload <plugin_name>
```

#### Listar Plugins

```bash
plugin_system list
```

### Performance Optimizer API

Sistema de otimização com cache e lazy loading.

#### Cache de Componente

```bash
performance_optimizer cache component <name> <data> [cache_key]
```

#### Recuperar do Cache

```bash
performance_optimizer cache get <cache_key>
```

#### Carregamento Lazy

```bash
performance_optimizer lazy-load <component_name>
```

## 🧩 Component Interface

Todos os componentes devem implementar a interface padrão:

### Interface Obrigatória

```bash
# Inicializar componente
<component>_init()

# Validar configuração
<component>_validate()

# Aplicar tema
<component>_apply_theme <theme_name>

# Limpeza de recursos
<component>_cleanup()

# Verificação de saúde
<component>_health_check()
```

### Exemplo de Implementação

```bash
#!/bin/bash
# components/example/example-component.sh

COMPONENT_NAME="example"
COMPONENT_VERSION="1.0.0"
CONFIG_PATH="$HOME/.config/example"

# Inicializar componente
example_init() {
    log_info "[ExampleComponent] Inicializando..."
    mkdir -p "$CONFIG_PATH"
    # Lógica de inicialização
    return 0
}

# Validar configuração
example_validate() {
    log_info "[ExampleComponent] Validando configuração..."
    if [ -f "$CONFIG_PATH/config.conf" ]; then
        return 0
    else
        log_error "[ExampleComponent] Configuração não encontrada"
        return 1
    fi
}

# Aplicar tema
example_apply_theme() {
    local theme_name="$1"
    log_info "[ExampleComponent] Aplicando tema: $theme_name"
    # Lógica de aplicação de tema
    return 0
}

# Limpeza
example_cleanup() {
    log_info "[ExampleComponent] Executando limpeza..."
    # Lógica de limpeza
    return 0
}

# Health check
example_health_check() {
    if [ -d "$CONFIG_PATH" ] && [ -f "$CONFIG_PATH/config.conf" ]; then
        echo "healthy"
        return 0
    else
        echo "unhealthy"
        return 1
    fi
}
```

## 🔌 Plugin Development API

### Plugin Metadata (Obrigatório)

```bash
PLUGIN_NAME="plugin-name"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Descrição do plugin"
PLUGIN_AUTHOR="Autor"
PLUGIN_CATEGORY="categoria"
PLUGIN_DEPENDENCIES="plugin1,plugin2"
PLUGIN_HOOKS="system.init,theme.changed"
```

### Plugin Interface

```bash
# Inicialização do plugin
plugin_init() {
    # Lógica de inicialização
    return 0
}

# Limpeza do plugin
plugin_cleanup() {
    # Lógica de limpeza
    return 0
}

# Hooks do plugin
hook_system_init() {
    local event_data="$1"
    # Processar evento system.init
}

hook_theme_changed() {
    local event_data="$1"
    # Processar evento theme.changed
}
```

### Plugin Security

Plugins são validados automaticamente contra:

- Comandos perigosos (`rm -rf /`, `format`, etc.)
- Acesso a arquivos sensíveis (`/etc/passwd`, `/root/`, etc.)
- Conexões de rede suspeitas

## 🎯 System Controller API

Controlador principal do sistema modular.

### Comandos Principais

```bash
# Inicializar sistema
system_controller init

# Iniciar sistema
system_controller start

# Parar sistema
system_controller stop

# Reiniciar sistema
system_controller restart

# Status do sistema
system_controller status

# Validar sistema
system_controller validate
```

## 📊 Testing APIs

### Integration Test Suite

```bash
# Executar todos os testes
./tests/integration/integration-test-suite.sh all

# Testes de serviços
./tests/integration/integration-test-suite.sh services

# Testes de componentes
./tests/integration/integration-test-suite.sh components

# Testes end-to-end
./tests/integration/integration-test-suite.sh e2e
```

## 🚀 Performance APIs

### Métricas de Performance

O sistema coleta automaticamente:

- Tempo de carregamento de componentes
- Taxa de cache hit/miss
- Uso de memória e CPU
- Tempo de resposta dos serviços

### Otimizações Disponíveis

- **Cache Inteligente**: Cache automático com TTL configurável
- **Lazy Loading**: Carregamento sob demanda de componentes
- **Paralelização**: Carregamento paralelo de componentes independentes
- **Compressão**: Compressão automática de configurações grandes
- **Debounce**: Prevenção de mudanças de configuração muito frequentes

## 🔍 Error Handling

### Códigos de Retorno Padrão

| Código | Descrição                   |
| ------ | --------------------------- |
| `0`    | Sucesso                     |
| `1`    | Erro geral                  |
| `2`    | Erro de validação           |
| `3`    | Arquivo não encontrado      |
| `4`    | Permissão negada            |
| `5`    | Timeout                     |
| `10`   | Componente não inicializado |
| `11`   | Dependência não encontrada  |

### Tratamento de Erros

```bash
# Exemplo de tratamento de erro
if ! component_init; then
    case $? in
        2) log_error "Erro de validação" ;;
        3) log_error "Arquivo de configuração não encontrado" ;;
        *) log_error "Erro desconhecido na inicialização" ;;
    esac
    return 1
fi
```

## 📁 File Structure APIs

### Diretórios Padrão

```
PROJECT_ROOT/
├── core/                    # APIs fundamentais
├── services/               # Serviços do sistema
├── components/             # Componentes modulares
├── plugins/                # Plugins externos
├── config/                 # Configurações centralizadas
├── cache/                  # Cache do sistema
├── data/                   # Dados persistentes
├── logs/                   # Logs do sistema
├── tests/                  # Testes automatizados
└── docs/                   # Documentação
```

### Variáveis de Ambiente

```bash
PROJECT_ROOT              # Diretório raiz do projeto
HYPR_CONFIG_DIR          # Diretório de configuração do Hyprland
CACHE_DIR                # Diretório de cache
LOG_LEVEL                # Nível de log (DEBUG, INFO, WARN, ERROR)
PERFORMANCE_MODE         # Modo de performance (true/false)
```

---

_Esta documentação é atualizada automaticamente conforme a evolução da API do sistema._
