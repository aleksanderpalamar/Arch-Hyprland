# 🏗️ Arquitetura - Arch-Hyprland

Visão geral da arquitetura e componentes do sistema.

## 📊 Estrutura do Sistema

```
┌─────────────────────────────────────────┐
│           Hyprland Desktop              │
├─────────────────────────────────────────┤
│  Waybar  │  Rofi  │  Scripts │ Wallust │
│ (Barra)  │ (Menu) │  (Auto)  │ (Temas) │
├─────────────────────────────────────────┤
│      Hyprland Compositor (Wayland)      │
├─────────────────────────────────────────┤
│              Arch Linux                 │
└─────────────────────────────────────────┘
```

## 🧩 Componentes Principais

### Core (Núcleo)

- **Hyprland**: Compositor Wayland principal
- **Configurações**: Arquivos em `~/.config/hypr/`
- **Scripts**: Automações em `~/.config/hypr/scripts/`

### Interface

- **Waybar**: Barra de status superior
- **Rofi**: Menu de aplicações e seletor
- **Hyprpaper**: Gerenciador de wallpapers
- **SwayNC**: Sistema de notificações

### Utilitários

- **Wallust**: Gerador de temas a partir de wallpapers
- **Kitty**: Terminal padrão
- **Thunar**: Gerenciador de arquivos

## 📁 Estrutura de Arquivos

```
~/.config/hypr/
├── hyprland.conf          # Configuração principal
├── hyprpaper.conf         # Configuração de wallpapers
├── monitors.conf          # Configuração de monitores
├── workspaces.conf        # Configuração de workspaces
├── UserConfigs/           # Configurações do usuário
│   ├── MyPrograms.conf    # Programas padrão
│   ├── UserKeybinds.conf  # Atalhos de teclado
│   ├── UserInput.conf     # Configuração de entrada
│   └── ...
└── scripts/               # Scripts de automação
    ├── SelectWallpaper.sh # Seletor de wallpapers
    ├── Volume.sh          # Controle de volume
    └── ...

~/.config/waybar/
├── config.jsonc           # Configuração da waybar
├── style.css             # Estilos CSS
├── Modules               # Módulos da waybar
└── ...

~/.config/rofi/
├── config.rasi           # Configuração do rofi
├── theme.rasi           # Tema visual
└── wallust/             # Cores geradas pelo wallust
    └── colors-rofi.rasi # Paleta de cores atual
```

## 🔄 Fluxo de Funcionamento

### Inicialização

1. **Hyprland** inicia como compositor
2. **Hyprpaper** carrega wallpaper padrão
3. **Waybar** inicia a barra de status
4. **Scripts** executam automações

### Mudança de Wallpaper

1. Usuário seleciona wallpaper (`Super + W`)
2. **Wallust** gera paleta de cores
3. **Hyprpaper** aplica nova imagem
4. **Waybar** e **Rofi** atualizam cores

### Configuração

1. Usuário edita arquivos em `UserConfigs/`
2. **Hyprland** recarrega configurações
3. Mudanças aplicadas em tempo real

## 🔧 Personalização

### Adicionar Componentes

```bash
# Exemplo: Adicionar componente personalizado
mkdir -p ~/.config/hypr/custom/
echo 'exec-once = meu-programa' >> ~/.config/hypr/UserConfigs/Startup_Apps.conf
```

### Modificar Comportamento

```bash
# Editar configurações específicas
nano ~/.config/hypr/UserConfigs/UserKeybinds.conf  # Atalhos
nano ~/.config/hypr/UserConfigs/UserInput.conf     # Entrada
nano ~/.config/waybar/config.jsonc                 # Waybar
```

### Scripts Personalizados

```bash
# Criar script personalizado
nano ~/.config/hypr/scripts/meu-script.sh
chmod +x ~/.config/hypr/scripts/meu-script.sh

# Vincular a atalho
echo 'bind = $mainMod, U, exec, ~/.config/hypr/scripts/meu-script.sh' >> ~/.config/hypr/UserConfigs/UserKeybinds.conf
```

## 🛠️ Para Desenvolvedores

### APIs Disponíveis

- **hyprctl**: Interface CLI do Hyprland
- **Event System**: Sistema de eventos interno
- **Component System**: Sistema modular de componentes

### Estrutura de Plugin

```bash
# Exemplo de estrutura para plugin
plugins/
├── meu-plugin/
│   ├── plugin.sh          # Script principal
│   ├── config.conf        # Configurações
│   └── install.sh         # Instalação
```

### Integração

```bash
# Registrar plugin no sistema
echo 'exec-once = ~/.config/hypr/plugins/meu-plugin/plugin.sh' >> ~/.config/hypr/UserConfigs/Startup_Apps.conf
```

## 📋 Referências Técnicas

- **[API Reference](../api/API.md)** - APIs e interfaces disponíveis
- **[Hyprland Wiki](https://wiki.hyprland.org/)** - Documentação oficial
- **[Waybar Wiki](https://github.com/Alexays/Waybar/wiki)** - Configuração da waybar

---

💡 **Para uso diário, consulte o [Guia do Usuário](../USER_GUIDE.md)**
