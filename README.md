# 🏔️ Arch-Hyprland

**Sistema completo de configuração Hyprland para Arch Linux**

Um ambiente desktop moderno, otimizado e totalmente funcional baseado no compositor Hyprland com sistema modular e instalação automatizada.

![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-blue?style=for-the-badge)
![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![License](https://img.shields.io/github/license/aleksanderpalamar/Arch-Hyprland?style=for-the-badge)

## ✨ Características

- 🎯 **Instalação Automática** - Script único instala tudo
- 🎨 **Temas Dinâmicos** - Cores geradas automaticamente do wallpaper
- ⚡ **Performance Otimizada** - Sistema de cache e lazy loading
- 🔧 **Modular** - Componentes independentes e customizáveis
- 🖼️ **Wallpapers** - Seletor visual integrado
- ⌨️ **Atalhos Intuitivos** - Configuração inspirada no i3/sway
- � **Waybar** - Barra de status moderna e informativa
- 🔍 **Rofi** - Menu de aplicações elegante

## 🚀 Instalação Rápida

```bash
# Clone o repositório
git clone https://github.com/aleksanderpalamar/Arch-Hyprland.git
cd Arch-Hyprland

# Execute a instalação (faz backup automaticamente)
./install.sh
```

### Após a Instalação

1. **Faça logout** do desktop atual
2. **Selecione "Hyprland"** no display manager
3. **Use Super + Enter** para abrir o terminal

## � Componentes Inclusos

- **🪟 Hyprland** - Compositor Wayland moderno
- **� Waybar** - Barra de status personalizável
- **🔍 Rofi** - Lançador de aplicações elegante
- **🖼️ Hyprpaper** - Gerenciador de wallpapers
- **🎨 Wallust** - Gerador automático de temas
- **🔔 SwayNC** - Centro de notificações
- **📁 Thunar** - Gerenciador de arquivos
- **⌨️ Kitty** - Terminal moderno e rápido

## ⌨️ Atalhos Principais

| Atalho                | Ação                    |
| --------------------- | ----------------------- |
| `Super + Enter`       | Terminal                |
| `Super + Q`           | Fechar janela           |
| `Super + M`           | Sair do Hyprland        |
| `Super + R`           | Menu de aplicações      |
| `Super + W`           | Seletor de wallpapers   |
| `Super + E`           | Gerenciador de arquivos |
| `Super + 1-9`         | Trocar workspace        |
| `Super + Shift + 1-9` | Mover janela            |

## 🎨 Personalização Rápida

### Alterar Wallpaper

```bash
Super + W  # Abre seletor visual
```

### Configurar Temas

```bash
# Editar configurações
nano ~/.config/hypr/UserConfigs/UserDecorations.conf
```

### Personalizar Waybar

```bash
# Editar layout
nano ~/.config/waybar/config.jsonc
# Editar estilo
nano ~/.config/waybar/style.css
```

| Atalho                | Ação                        |
| --------------------- | --------------------------- |
| `Super + Enter`       | Terminal                    |
| `Super + Q`           | Fechar janela               |
| `Super + R`           | Menu de aplicações          |
| `Super + W`           | Seletor de wallpapers       |
| `Super + 1-9`         | Trocar workspace            |
| `Super + Shift + 1-9` | Mover janela para workspace |

### 🔧 Configurações Rápidas

```bash
# Recarregar configuração do Hyprland
hyprctl reload

# Recarregar Waybar
killall waybar && waybar &

# Aplicar novo wallpaper
~/.config/hypr/scripts/SelectWallpaper.sh
```

## 🆘 Problemas Comuns

### Hyprland não inicia

```bash
# Verificar logs
journalctl -u display-manager
# ou
~/.local/share/hyprland/hyprland.log
```

### Waybar não aparece

```bash
# Restartar waybar
killall waybar
waybar &
```

### Sem áudio

```bash
# Verificar PipeWire
systemctl --user status pipewire
systemctl --user restart pipewire
```

## 📁 Estrutura de Arquivos

```
~/.config/hypr/          # Configurações principais
├── hyprland.conf        # Configuração principal
├── UserConfigs/         # Suas personalizações
├── scripts/             # Scripts de automação
└── ...

~/.config/waybar/        # Barra superior
~/.config/rofi/          # Menu de aplicações
~/Imagens/wallpapers/    # Seus wallpapers
```

## 🔄 Atualização

```bash
# Atualizar para versão mais recente
cd Arch-Hyprland
git pull
./install.sh  # Faz backup automático antes de atualizar
```

## � Documentação

- **[📖 Guia do Usuário](docs/USER_GUIDE.md)** - Tutorial completo de uso
- **[🏗️ Arquitetura](docs/architecture/ARCHITECTURE.md)** - Como funciona internamente
- **[📋 API Reference](docs/api/API.md)** - APIs para desenvolvedores

## 🛠️ Requisitos

### Sistema Base

- **Arch Linux** (ou derivado)
- **yay** ou **paru** (AUR helper)

### Dependências (instaladas automaticamente)

- `hyprland` `waybar` `rofi` `kitty`
- `hyprpaper` `swaync` `thunar`
- `grim` `slurp` `swaylock`
- `pipewire` `wireplumber` `pamixer`

## 🤝 Contribuindo

1. **Fork** o projeto
2. **Crie** uma branch para sua feature
3. **Commit** suas mudanças
4. **Push** para a branch
5. **Abra** um Pull Request

## � Licença

Este projeto está sob a licença MIT. Veja [LICENSE](LICENSE) para mais detalhes.

## 🙏 Agradecimentos

- **[Hyprland](https://hyprland.org/)** - Compositor Wayland incrível
- **[Waybar](https://github.com/Alexays/Waybar)** - Barra de status customizável
- **[Rofi](https://github.com/davatorium/rofi)** - Lançador versátil
- **Comunidade Arch Linux** - Base sólida e suporte

---

⭐ **Gostou do projeto? Dê uma estrela para apoiar!**

---
