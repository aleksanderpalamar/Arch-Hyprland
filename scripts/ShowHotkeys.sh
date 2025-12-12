#!/bin/bash

CONFIG_FILE="$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"

if pidof rofi > /dev/null; then
    pkill rofi
fi

# Function to get friendly description
get_friendly_description() {
    local action="$1"
    local command="$2"
    local key="$3"
    local mod="$4"
    
    # Application launchers
    [[ "$command" == *"terminal"* || "$command" == *"kitty"* ]] && echo "🖥️  Abrir terminal" && return
    [[ "$command" == *"fileManager"* || "$command" == *"thunar"* || "$command" == *"nautilus"* ]] && echo "📁 Abrir gerenciador de arquivos" && return
    [[ "$command" == *"search"* || "$command" == *"Search"* ]] && echo "🔎 Pesquisar na web" && return
    [[ "$command" == *"msedge"* || "$command" == *"browser"* ]] && echo "🌐 Abrir menu" && return
    [[ "$command" == *"warpterminal"* ]] && echo "⚡ Abrir Warp Terminal" && return
    [[ "$command" == *"rofi -show drun"* ]] && echo "🚀 Abrir menu de aplicativos" && return
    
    # Window management
    [[ "$action" == "killactive" ]] && echo "❌ Fechar janela atual" && return
    [[ "$action" == "exit" ]] && echo "🚪 Sair do Hyprland" && return
    [[ "$action" == "togglefloating" ]] && echo "🪟  Alternar modo flutuante" && return
    [[ "$action" == "pseudo" ]] && echo "🔲 Modo pseudo (dwindle)" && return
    [[ "$action" == "togglesplit" ]] && echo "⚡ Alternar divisão (dwindle)" && return
    
    # Focus movement
    [[ "$action" == "movefocus" && "$command" == "l" ]] && echo "⬅️  Mover foco para esquerda" && return
    [[ "$action" == "movefocus" && "$command" == "r" ]] && echo "➡️  Mover foco para direita" && return
    [[ "$action" == "movefocus" && "$command" == "u" ]] && echo "⬆️  Mover foco para cima" && return
    [[ "$action" == "movefocus" && "$command" == "d" ]] && echo "⬇️  Mover foco para baixo" && return
    
    # Workspaces
    [[ "$action" == "workspace" && "$command" =~ ^[0-9]+$ ]] && echo "🔢 Ir para workspace $command" && return
    [[ "$action" == "workspace" && "$command" == "e+1" ]] && echo "➕ Próximo workspace" && return
    [[ "$action" == "workspace" && "$command" == "e-1" ]] && echo "➖ Workspace anterior" && return
    [[ "$action" == "movetoworkspace" && "$command" =~ ^[0-9]+$ ]] && echo "📤 Mover janela para workspace $command" && return
    [[ "$action" == "togglespecialworkspace" ]] && echo "✨ Alternar workspace especial" && return
    [[ "$action" == "movetoworkspace" && "$command" == *"special"* ]] && echo "📥 Mover para workspace especial" && return
    
    # Scripts
    [[ "$command" == *"waybar"* ]] && echo "🎨 Reiniciar Waybar" && return
    [[ "$command" == *"grim"* ]] && echo "📸 Capturar screenshot" && return
    [[ "$command" == *"SelectWallpaper"* ]] && echo "🖼️  Selecionar papel de parede" && return
    [[ "$command" == *"Wlogout"* ]] && echo "🔌 Menu de logout" && return
    [[ "$command" == *"LockScreen"* ]] && echo "🔒 Bloquear tela" && return
    [[ "$command" == *"ShowHotkeys"* ]] && echo "⌨️  Mostrar atalhos de teclado" && return
    
    # Mouse actions
    [[ "$action" == "movewindow" ]] && echo "🖱️  Mover janela com mouse" && return
    [[ "$action" == "resizewindow" ]] && echo "↔️  Redimensionar janela com mouse" && return
    
    # Multimedia
    [[ "$command" == *"AudioRaiseVolume"* || "$command" == *"set-volume"*"+"* ]] && echo "🔊 Aumentar volume" && return
    [[ "$command" == *"AudioLowerVolume"* || "$command" == *"set-volume"*"-"* ]] && echo "🔉 Diminuir volume" && return
    [[ "$command" == *"AudioMute"*"SINK"* || "$command" == *"set-mute"*"SINK"* ]] && echo "🔇 Silenciar/ativar áudio" && return
    [[ "$command" == *"AudioMicMute"* || "$command" == *"set-mute"*"SOURCE"* ]] && echo "🎤 Silenciar/ativar microfone" && return
    [[ "$command" == *"MonBrightnessUp"* || "$command" == *"brightnessctl"*"+"* ]] && echo "☀️  Aumentar brilho" && return
    [[ "$command" == *"MonBrightnessDown"* || "$command" == *"brightnessctl"*"-"* ]] && echo "🌙 Diminuir brilho" && return
    [[ "$command" == *"playerctl next"* ]] && echo "⏭️  Próxima música" && return
    [[ "$command" == *"playerctl play-pause"* ]] && echo "⏯️  Play/Pause" && return
    [[ "$command" == *"playerctl previous"* ]] && echo "⏮️  Música anterior" && return
    
    # Default fallback
    echo "⚙️  $action $command"
}

parse_keybinds() {
    local config_file="$1"
    local main_mod="SUPER"

    
    grep '^bind' "$config_file" | while IFS= read -r line; do        
        line=$(echo "$line" | sed 's/^bind[mel]* = //' | sed 's/,$//')
        
        line=$(echo "$line" | sed "s/\$mainMod/$main_mod/")
        
        IFS=',' read -r mod key action command <<< "$line"
        
        mod=$(echo "$mod" | xargs)
        key=$(echo "$key" | xargs)
        action=$(echo "$action" | xargs)
        command=$(echo "$command" | xargs)
        
        [[ -z "$key" ]] && continue
        
        if [[ "$mod" == "$main_mod" ]]; then
            keybind="SUPER + $key"
        elif [[ -z "$mod" ]]; then
            keybind="$key"
        else
            keybind="$mod + $key"
        fi
        
        description=$(get_friendly_description "$action" "$command" "$key" "$mod")
        
        printf "%-30s │ %s\n" "$keybind" "$description"
    done
}

parse_keybinds "$CONFIG_FILE" | rofi -dmenu -i -p "⌨️  Atalhos do Hyprland" -theme-str 'window {width: 800px;}'