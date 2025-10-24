# 📖 Guia do Usuário - Arch-Hyprland

Guia prático para usar e personalizar seu ambiente Hyprland.

## 🚀 Primeiros Passos

### Após a Instalação

1. **Fazer logout** do desktop atual
2. **Selecionar "Hyprland"** no display manager (GDM/SDDM/LightDM)
3. **Aguardar o carregamento** - pode demorar alguns segundos na primeira vez

### Primeira Inicialização

Na primeira vez que entrar no Hyprland:

- **Waybar** (barra superior) carregará automaticamente
- **Wallpaper** será aplicado
- **Terminal** pode ser aberto com `Super + Enter`

## ⌨️ Atalhos Essenciais

### Navegação Básica

| Atalho          | Ação                             |
| --------------- | -------------------------------- |
| `Super + Enter` | Abrir terminal (Kitty)           |
| `Super + Q`     | Fechar janela ativa              |
| `Super + M`     | Sair do Hyprland                 |
| `Super + R`     | Menu de aplicações (Rofi)        |
| `Super + E`     | Gerenciador de arquivos (Thunar) |

### Workspaces (Áreas de Trabalho)

| Atalho                  | Ação                        |
| ----------------------- | --------------------------- |
| `Super + 1-9`           | Ir para workspace 1-9       |
| `Super + Shift + 1-9`   | Mover janela para workspace |
| `Super + Mouse`         | Mover janela arrastando     |
| `Super + Shift + Mouse` | Redimensionar janela        |

### Sistema

| Atalho           | Ação                  |
| ---------------- | --------------------- |
| `Super + W`      | Seletor de wallpapers |
| `Super + L`      | Bloquear tela         |
| `Ctrl + Alt + L` | Menu de logout/power  |
| `Print Screen`   | Captura de tela       |

## 🎨 Personalização

### 🖼️ Wallpapers

#### Método 1: Seletor Visual

```bash
Super + W  # Abre o seletor gráfico
# Clique na imagem desejada
```

#### Método 2: Manual

```bash
# Adicionar suas imagens à pasta
cp minha-imagem.jpg ~/Imagens/wallpapers/

# Aplicar diretamente
~/.config/hypr/scripts/SelectWallpaper.sh
```

### 🎨 Temas e Cores

O sistema usa **wallust** para gerar cores automaticamente do wallpaper:

```bash
# Gerar nova paleta de cores
wallust run ~/Imagens/wallpapers/minha-imagem.jpg

# Recarregar waybar com novas cores
killall waybar && waybar &
```

### ⚙️ Configurações

Todas as configurações ficam em `~/.config/hypr/UserConfigs/`:

#### Programas Padrão (`MyPrograms.conf`)

```bash
# Editar programas padrão
nano ~/.config/hypr/UserConfigs/MyPrograms.conf

# Exemplo de mudança:
$terminal = alacritty  # em vez de kitty
$browser = firefox     # em vez de microsoft-edge
```

#### Atalhos de Teclado (`UserKeybinds.conf`)

```bash
# Adicionar novos atalhos
nano ~/.config/hypr/UserConfigs/UserKeybinds.conf

# Exemplo:
bind = $mainMod, T, exec, thunar
bind = $mainMod, B, exec, firefox
```

#### Aparência (`UserDecorations.conf`)

```bash
# Personalizar bordas, sombras, etc.
nano ~/.config/hypr/UserConfigs/UserDecorations.conf
```

### 📊 Waybar (Barra Superior)

#### Configuração Principal

```bash
# Editar layout da waybar
nano ~/.config/waybar/config.jsonc

# Editar estilos CSS
nano ~/.config/waybar/style.css
```

#### Recarregar Waybar

```bash
# Após fazer alterações
killall waybar && waybar &
```

## 🔧 Casos de Uso Práticos

### 📱 Configurar Múltiplos Monitores

```bash
# Abrir configurador visual
nwg-displays

# Ou editar manualmente
nano ~/.config/hypr/monitors.conf
```

### 🎮 Configurar Jogos

```bash
# Adicionar regras para jogos
nano ~/.config/hypr/UserConfigs/WindowRules.conf

# Exemplo para jogos Steam:
windowrule = fullscreen,^(steam_app_)(.*)$
windowrule = workspace 10,^(steam_app_)(.*)$
```

### 💻 Produtividade

#### Auto-iniciar Aplicações

```bash
# Editar aplicações que iniciam automaticamente
nano ~/.config/hypr/UserConfigs/Startup_Apps.conf

# Exemplo:
exec-once = discord
exec-once = steam
exec-once = firefox
```

#### Organizar Workspaces

```bash
# Definir aplicações para workspaces específicos
windowrule = workspace 2,^(firefox)$
windowrule = workspace 3,^(discord)$
windowrule = workspace 4,^(steam)$
```

## 🆘 Solução de Problemas

### Hyprland não Inicia

1. **Verificar logs**:

```bash
# Log principal
cat ~/.local/share/hyprland/hyprland.log

# Log do sistema
journalctl -u display-manager
```

2. **Sintaxe de configuração**:

```bash
# Testar configuração
hyprctl reload
```

### Waybar não Aparece

```bash
# Verificar se está rodando
pgrep waybar

# Forçar restart
killall waybar
waybar &

# Verificar erros
waybar 2>&1 | grep -i error
```

### Sem Áudio

```bash
# Verificar PipeWire
systemctl --user status pipewire

# Reiniciar áudio
systemctl --user restart pipewire
systemctl --user restart wireplumber

# Testar controle de volume
pamixer --get-volume
```

### Aplicações não Abrem

```bash
# Verificar se o programa está instalado
which nome_do_programa

# Tentar executar pelo terminal para ver erros
nome_do_programa
```

### Wallpaper não Muda

```bash
# Verificar hyprpaper
pgrep hyprpaper

# Reiniciar hyprpaper
killall hyprpaper
hyprpaper &

# Aplicar wallpaper manualmente
hyprctl hyprpaper wallpaper "monitor,/caminho/para/imagem.jpg"
```

## 🔄 Manutenção

### Backup de Configurações

```bash
# Backup manual
cp -r ~/.config/hypr ~/backup-hypr-$(date +%Y%m%d)
cp -r ~/.config/waybar ~/backup-waybar-$(date +%Y%m%d)
```

### Atualização do Sistema

```bash
# Atualizar repositório
cd /caminho/para/Arch-Hyprland
git pull

# Executar instalação novamente (faz backup automático)
./install.sh
```

### Reset para Padrão

```bash
# Se algo der errado, voltar ao backup
cd ~/.config
rm -rf hypr waybar rofi

# Reinstalar
cd /caminho/para/Arch-Hyprland
./install.sh
```

## 📱 Integração com Aplicações

### Navegadores Web

- **Firefox**: Funciona perfeitamente
- **Chrome/Chromium**: Adicionar `--enable-features=UseOzonePlatform --ozone-platform=wayland`
- **Edge**: Configurado automaticamente

### Desenvolvimento

- **VS Code**: Funciona nativamente no Wayland
- **Terminal**: Kitty (padrão) ou personalize em `MyPrograms.conf`
- **Git**: Configurado normalmente

### Multimídia

- **OBS Studio**: Suporte nativo à captura Wayland
- **VLC**: Funciona perfeitamente
- **Spotify**: Via browser ou Flatpak

### Gaming

- **Steam**: Funciona normalmente
- **Lutris**: Para jogos não-Steam
- **GameMode**: Melhora performance automaticamente

## 💡 Dicas Avançadas

### Performance

```bash
# Verificar FPS
hyprctl monitors

# Otimizar para gaming
# Em ~/.config/hypr/UserConfigs/UserDecorations.conf:
decoration {
    blur {
        enabled = false  # Desabilitar blur para mais FPS
    }
}
```

### Automação

```bash
# Criar scripts personalizados em ~/.config/hypr/scripts/
# Exemplo: ~/.config/hypr/scripts/workspace-organizer.sh

#!/bin/bash
hyprctl dispatch workspace 1
firefox &
sleep 2
hyprctl dispatch workspace 2
discord &
```

### Temas Dinâmicos

```bash
# Wallpaper aleatório no boot
# Em ~/.config/hypr/UserConfigs/Startup_Apps.conf:
exec-once = ~/.config/hypr/scripts/SelectWallpaper.sh --random
```

---

🎉 **Agora você domina o Arch-Hyprland!** Para dúvidas, consulte a [documentação técnica](api/API.md) ou abra uma [issue no GitHub](https://github.com/aleksanderpalamar/Arch-Hyprland/issues).
