# 📖 User Guide - Arch-Hyprland

Guia completo para usar e personalizar o sistema modular Arch-Hyprland.

## 🚀 Introdução

O Arch-Hyprland é um sistema modular e extensível para configuração do ambiente desktop Hyprland. Ele oferece:

- **Sistema modular** com componentes independentes
- **Gerenciamento de temas** centralizado e automatizado
- **Performance otimizada** com cache inteligente
- **Backup automático** de configurações
- **Sistema de plugins** para extensibilidade
- **Monitoramento em tempo real** de componentes

## 📦 Instalação

### Pré-requisitos

```bash
# Arch Linux com yay instalado
sudo pacman -S hyprland waybar rofi kitty hyprpaper
yay -S wlogout wallust swaync
```

### Instalação Automática

```bash
# Clonar o repositório
git clone https://github.com/aleksanderpalamar/Arch-Hyprland.git
cd Arch-Hyprland

# Executar instalação automática
bash install.sh
```

O script de instalação irá:

1. Fazer backup das configurações existentes
2. Instalar as dependências necessárias
3. Copiar as novas configurações
4. Configurar o sistema modular

## 🎮 Uso Básico

### Sistema Controller

O System Controller é o ponto central para gerenciar todo o sistema:

```bash
# Inicializar sistema
./tools/system-controller.sh init

# Iniciar sistema
./tools/system-controller.sh start

# Ver status
./tools/system-controller.sh status

# Parar sistema
./tools/system-controller.sh stop
```

### Atalhos de Teclado Principais

| Atalho                | Ação                        |
| --------------------- | --------------------------- |
| `Super + Return`      | Abrir terminal              |
| `Super + D`           | Launcher (Rofi)             |
| `Super + W`           | Seletor de wallpaper        |
| `Super + L`           | Bloquear tela               |
| `Super + Shift + Q`   | Fechar janela               |
| `Super + F`           | Fullscreen                  |
| `Super + 1-9`         | Trocar workspace            |
| `Super + Shift + 1-9` | Mover janela para workspace |

## 🎨 Gerenciamento de Temas

### Aplicar Tema

```bash
# Listar temas disponíveis
./services/theme-engine.sh discover

# Aplicar tema específico
./services/theme-engine.sh apply_theme nome_do_tema

# Ver tema atual
./services/theme-engine.sh status
```

### Seleção de Wallpaper

```bash
# Seleção interativa via Rofi
Super + W

# Ou via script direto
./hypr/scripts/SelectWallpaper.sh
```

O sistema automaticamente:

1. Aplica o wallpaper selecionado
2. Gera esquema de cores com `wallust`
3. Atualiza Waybar, Rofi e outros componentes
4. Salva as preferências

### Personalizar Cores

As cores são geradas automaticamente pelo `wallust` baseado no wallpaper, mas você pode personalizar:

```bash
# Editar configuração do wallust
nano ~/.config/wallust/wallust.toml

# Aplicar cores customizadas
wallust run /caminho/para/wallpaper.jpg
```

## 🔧 Configuração de Componentes

### Waybar

```bash
# Configuração principal
nano ~/.config/waybar/config.jsonc

# Personalizar estilo
nano ~/.config/waybar/style.css

# Recarregar Waybar
Super + Ctrl + R
```

#### Módulos Disponíveis

A configuração do Waybar é modular com arquivos separados:

- `Modules` - Módulos principais
- `ModulesCustom` - Módulos customizados
- `ModulesGroups` - Agrupamentos
- `ModulesWorkspaces` - Configuração de workspaces

### Rofi

```bash
# Configuração principal
nano ~/.config/rofi/config.rasi

# Temas
ls ~/.config/rofi/wallust/

# Testar configuração
rofi -show drun
```

### Hyprland

```bash
# Configuração principal (não edite diretamente)
cat ~/.config/hypr/hyprland.conf

# Personalizações vão nos UserConfigs
nano ~/.config/hypr/UserConfigs/UserKeybinds.conf
nano ~/.config/hypr/UserConfigs/UserDecorations.conf
nano ~/.config/hypr/UserConfigs/MyPrograms.conf
```

## 🔌 Sistema de Plugins

### Descobrir Plugins

```bash
# Listar plugins disponíveis
./services/plugin-system.sh list

# Status dos plugins
./services/plugin-system.sh status
```

### Instalar Plugin

```bash
# Carregar plugin
./services/plugin-system.sh load nome_do_plugin

# Verificar se carregou
./services/plugin-system.sh status
```

### Criar Plugin Personalizado

```bash
# Copiar template
cp plugins/templates/basic-plugin.sh plugins/user/meu-plugin.sh

# Editar metadata
nano plugins/user/meu-plugin.sh

# Carregar plugin
./services/plugin-system.sh load meu-plugin
```

#### Estrutura de Plugin

```bash
#!/bin/bash

# Metadata obrigatória
PLUGIN_NAME="meu-plugin"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Meu plugin personalizado"
PLUGIN_AUTHOR="Seu Nome"
PLUGIN_HOOKS="system.startup,wallpaper.changed"

# Inicialização
plugin_init() {
    echo "Plugin inicializado!"
    return 0
}

# Hooks
hook_wallpaper_changed() {
    local event_data="$1"
    echo "Wallpaper alterado: $event_data"
}
```

## 💾 Sistema de Backup

### Criar Backup

```bash
# Backup completo automático
./services/backup-service.sh create_full_backup

# Backup com nome personalizado
./services/backup-service.sh create_full_backup "antes-da-atualizacao"
```

### Restaurar Backup

```bash
# Listar backups disponíveis
./services/backup-service.sh list_backups

# Restaurar backup específico
./services/backup-service.sh restore nome_do_backup
```

### Configuração de Backup

```bash
# Editar configuração
nano config/backup.conf

# Opções disponíveis:
# - BACKUP_RETENTION_DAYS: Dias para manter backups
# - COMPRESSION_ENABLED: Habilitar compressão
# - BACKUP_SCHEDULE: Agendamento automático
```

## 📊 Monitoramento e Performance

### Monitor Service

```bash
# Status dos componentes
./services/monitor-service.sh status

# Verificação manual
./services/monitor-service.sh check

# Relatório detalhado
./services/monitor-service.sh report
```

### Performance Optimizer

```bash
# Status das otimizações
./services/performance-optimizer.sh status

# Limpeza de cache
./services/performance-optimizer.sh gc

# Relatório de performance
./services/performance-optimizer.sh report
```

### Cache System

O sistema usa cache inteligente para melhor performance:

```bash
# Ver estatísticas de cache
./services/performance-optimizer.sh status

# Limpar cache específico
./services/performance-optimizer.sh cache invalidate cache_key

# Limpar todo o cache
./services/performance-optimizer.sh cache cleanup
```

## 🛠️ Troubleshooting

### Problemas Comuns

#### Waybar não aparece

```bash
# Verificar se está rodando
pgrep waybar

# Reiniciar
killall waybar && waybar &

# Verificar logs
journalctl -u waybar
```

#### Wallpaper não aplica

```bash
# Verificar hyprpaper
pgrep hyprpaper

# Reiniciar hyprpaper
pkill hyprpaper && hyprpaper &

# Verificar configuração
cat ~/.config/hypr/hyprpaper.conf
```

#### Rofi não abre

```bash
# Testar configuração
rofi -show drun -dry-run

# Verificar temas
ls ~/.config/rofi/wallust/

# Recarregar configuração
Super + D
```

### Logs do Sistema

```bash
# Logs do sistema modular
tail -f logs/system.log

# Logs de componentes específicos
tail -f logs/waybar.log
tail -f logs/wallpaper.log

# Logs de performance
tail -f logs/performance.log
```

### Sistema de Recovery

Se algo der errado, o sistema tem recovery automático:

```bash
# Restaurar último backup
./services/backup-service.sh restore latest

# Usar configuração de emergência
./tools/system-controller.sh emergency-mode

# Resetar para configuração padrão
./tools/system-controller.sh factory-reset
```

## 🧪 Testes

### Executar Testes

```bash
# Teste completo do sistema
./tests/integration/integration-test-suite.sh all

# Testes específicos
./tests/integration/integration-test-suite.sh services
./tests/integration/integration-test-suite.sh components
./tests/integration/integration-test-suite.sh e2e
```

### Validação de Configuração

```bash
# Validar todas as configurações
./tools/system-controller.sh validate

# Validar componente específico
./components/waybar/waybar-component.sh validate
```

## ⚡ Otimizações Avançadas

### Performance Mode

```bash
# Habilitar modo performance
export PERFORMANCE_MODE=true

# Configurar cache agressivo
echo "CACHE_TTL=600" >> config/performance.conf

# Habilitar carregamento paralelo
echo "PARALLEL_COMPONENT_LOADING=true" >> config/performance.conf
```

### Lazy Loading

```bash
# Configurar componentes críticos
nano config/performance.conf

# Adicionar à lista de críticos:
CRITICAL_COMPONENTS=(
    "hyprland"
    "waybar"
    "wallpaper"
)
```

### Configurações de Desenvolvimento

```bash
# Habilitar debug mode
export LOG_LEVEL=DEBUG

# Habilitar reload automático
export AUTO_RELOAD=true

# Desabilitar cache para desenvolvimento
export CACHE_ENABLED=false
```

## 📱 Integração com Aplicações

### Configuração de Aplicações

O sistema já vem configurado para:

- **Terminal**: Kitty com tema automático
- **Editor**: VSCode/Neovim com cores sincronizadas
- **Navegador**: Firefox com tema dark/light automático
- **Notificações**: SwayNC integrado
- **Screenshots**: grim + slurp configurados

### Adicionar Nova Aplicação

```bash
# Editar configuração de programas
nano hypr/UserConfigs/MyPrograms.conf

# Adicionar atalho
nano hypr/UserConfigs/UserKeybinds.conf

# Exemplo:
$meuapp = meu-aplicativo
bind = $mainMod, X, exec, $meuapp
```

## 🔄 Atualizações

### Sistema de Atualizações

```bash
# Verificar atualizações
git pull origin main

# Executar migração se necessário
./tools/migrate.sh

# Aplicar novas configurações
./tools/system-controller.sh restart
```

### Backup Antes de Atualizar

```bash
# Sempre fazer backup antes de atualizar
./services/backup-service.sh create_full_backup "pre-update-$(date +%Y%m%d)"
```

## 📞 Suporte

### Recursos de Ajuda

- **Documentação completa**: `docs/`
- **API Reference**: `docs/API.md`
- **Arquitetura**: `docs/architecture/ARCHITECTURE.md`
- **Issues**: GitHub Issues

### Comandos de Diagnóstico

```bash
# Health check completo
./tools/system-controller.sh health-check

# Informações do sistema
./tools/system-controller.sh system-info

# Relatório de diagnóstico
./tools/system-controller.sh generate-report
```

---

_Este guia cobre as funcionalidades principais. Para recursos avançados, consulte a documentação técnica em `docs/`._
