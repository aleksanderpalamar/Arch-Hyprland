# 📚 API Reference - Arch-Hyprland

APIs e interfaces essenciais para desenvolvedores.

## 🎯 APIs Principais

### hyprctl (Hyprland Control)

Interface principal para controlar o Hyprland programaticamente.

```bash
# Comandos básicos
hyprctl reload                    # Recarregar configuração
hyprctl monitors                  # Listar monitores
hyprctl workspaces                # Listar workspaces
hyprctl clients                   # Listar janelas abertas

# Dispatch (executar ações)
hyprctl dispatch workspace 1      # Ir para workspace 1
hyprctl dispatch killactive      # Fechar janela ativa
hyprctl dispatch exec kitty      # Executar aplicação

# Wallpaper
hyprctl hyprpaper wallpaper "eDP-1,~/wallpaper.jpg"
```

### Scripts de Sistema

#### SelectWallpaper.sh

```bash
# Uso básico
~/.config/hypr/scripts/SelectWallpaper.sh

# Parâmetros
~/.config/hypr/scripts/SelectWallpaper.sh --random    # Wallpaper aleatório
~/.config/hypr/scripts/SelectWallpaper.sh "imagem.jpg" # Wallpaper específico
```

#### Volume.sh

```bash
# Controle de volume
~/.config/hypr/scripts/Volume.sh up      # Aumentar volume
~/.config/hypr/scripts/Volume.sh down    # Diminuir volume
~/.config/hypr/scripts/Volume.sh mute    # Alternar mute
```

#### WaybarScripts.sh

```bash
# Scripts da waybar
~/.config/hypr/scripts/WaybarScripts.sh weather    # Clima
~/.config/hypr/scripts/WaybarScripts.sh updates    # Atualizações
```

## 🔧 Configuração Programática

### Adicionar Atalhos de Teclado

```bash
# Método 1: Editar arquivo
echo 'bind = $mainMod, T, exec, thunar' >> ~/.config/hypr/UserConfigs/UserKeybinds.conf

# Método 2: hyprctl (temporário)
hyprctl keyword bind 'SUPER, T, exec, thunar'
```

### Modificar Decorações

```bash
# Alterar opacity
hyprctl keyword decoration:active_opacity 0.9

# Alterar blur
hyprctl keyword decoration:blur:enabled false

# Alterar bordas
hyprctl keyword general:border_size 2
hyprctl keyword general:col.active_border "rgb(ff0000)"
```

### Gerenciar Workspaces

```bash
# Criar workspace
hyprctl dispatch workspace 10

# Mover janela para workspace
hyprctl dispatch movetoworkspace 5

# Workspace especial (scratchpad)
hyprctl dispatch togglespecialworkspace
```

## 🎨 Integração com Temas

### Wallust (Gerador de Cores)

```bash
# Gerar paleta de cores
wallust run /caminho/para/imagem.jpg

# Aplicar cores no waybar
wallust run /caminho/para/imagem.jpg -f waybar

# Templates personalizados
wallust run /caminho/para/imagem.jpg -t ~/.config/wallust/templates/
```

### Configuração de Cores

```bash
# Variáveis de cor disponíveis (após wallust)
source ~/.cache/wallust/colors.sh

# Usar em scripts
echo "Cor primária: $color1"
echo "Cor de fundo: $background"
```

## 📊 Monitoramento

### Status do Sistema

```bash
# Verificar status do Hyprland
pgrep hyprland && echo "Hyprland rodando" || echo "Hyprland parado"

# Verificar waybar
pgrep waybar && echo "Waybar ativa" || echo "Waybar inativa"

# Verificar recursos
hyprctl systeminfo    # Informações do sistema
```

### Eventos do Hyprland

```bash
# Escutar eventos em tempo real
hyprctl --batch "switchxkblayout;activewindow;workspace" --listen

# Script para reagir a eventos
socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    echo "Evento: $line"
done
```

## 🔌 Criar Extensões

### Estrutura Básica

```bash
# Criar diretório da extensão
mkdir -p ~/.config/hypr/extensions/minha-extensao/

# Script principal
cat > ~/.config/hypr/extensions/minha-extensao/main.sh << 'EOF'
#!/bin/bash
# Sua extensão aqui
echo "Extensão funcionando!"
EOF

# Tornar executável
chmod +x ~/.config/hypr/extensions/minha-extensao/main.sh
```

### Integrar ao Sistema

```bash
# Adicionar ao startup
echo 'exec-once = ~/.config/hypr/extensions/minha-extensao/main.sh' >> ~/.config/hypr/UserConfigs/Startup_Apps.conf

# Criar atalho
echo 'bind = $mainMod, X, exec, ~/.config/hypr/extensions/minha-extensao/main.sh' >> ~/.config/hypr/UserConfigs/UserKeybinds.conf
```

### Exemplo: Extensão de Produtividade

```bash
cat > ~/.config/hypr/extensions/workspace-manager/main.sh << 'EOF'
#!/bin/bash

case "$1" in
    "work")
        hyprctl dispatch workspace 1
        hyprctl dispatch exec firefox
        sleep 2
        hyprctl dispatch workspace 2
        hyprctl dispatch exec code
        ;;
    "media")
        hyprctl dispatch workspace 3
        hyprctl dispatch exec spotify
        hyprctl dispatch exec obs
        ;;
    *)
        echo "Uso: $0 {work|media}"
        ;;
esac
EOF

# Usar
~/.config/hypr/extensions/workspace-manager/main.sh work
```

## 🛠️ Debugging

### Logs e Diagnóstico

```bash
# Log do Hyprland
tail -f ~/.local/share/hyprland/hyprland.log

# Log da waybar
waybar 2>&1 | grep -i error

# Testar configuração
hyprctl reload && echo "✓ Config OK" || echo "✗ Erro na config"

# Verificar sintaxe dos scripts
bash -n ~/.config/hypr/scripts/script.sh
```

### Comandos Úteis para Debug

```bash
# Listar todas as janelas com detalhes
hyprctl clients -j | jq '.[] | {title, class, workspace}'

# Monitor de performance
hyprctl monitors | grep -E "(Monitor|fps)"

# Verificar binds ativos
hyprctl binds
```

## 📞 Integração com Aplicações

### Rofi (Menu)

```bash
# Usar rofi programaticamente
rofi -show drun                    # Menu de aplicações
rofi -show window                  # Seletor de janelas
rofi -dmenu < lista.txt            # Menu customizado

# Script personalizado com rofi
opcao=$(echo -e "Opção 1\nOpção 2\nOpção 3" | rofi -dmenu -p "Escolha:")
echo "Escolhido: $opcao"
```

### Waybar (Barra de Status)

```bash
# Enviar dados para waybar via JSON
echo '{"text": "Custom", "class": "active"}' > ~/.cache/waybar-custom.json

# Recarregar waybar
killall -SIGUSR2 waybar
```

## 🔗 Links Úteis

- **[Hyprland Wiki](https://wiki.hyprland.org/)** - Documentação oficial
- **[Waybar Examples](https://github.com/Alexays/Waybar/wiki/Examples)** - Exemplos de configuração
- **[Rofi Themes](https://github.com/davatorium/rofi-themes)** - Temas para rofi

---

💡 **Para uso básico, consulte o [Guia do Usuário](../USER_GUIDE.md)**
