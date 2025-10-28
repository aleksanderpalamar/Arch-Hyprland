#!/bin/bash
# Simplified & modular Hyprland hotkey viewer

CONFIG_FILE="$HOME/.config/hypr/UserConfigs/UserKeybinds.conf"

if pidof rofi > /dev/null; then
    pkill rofi
fi

# Function to parse keybinds
parse_keybinds() {
    local config_file="$1"
    local main_mod="SUPER"

    # Read the config file and parse binds
    grep '^bind' "$config_file" | while IFS= read -r line; do
        # Remove leading/trailing spaces and split by comma
        line=$(echo "$line" | sed 's/^bind[mel]* = //' | sed 's/,$//')
        
        # Replace $mainMod with SUPER
        line=$(echo "$line" | sed "s/\$mainMod/$main_mod/")
        
        # Split into parts
        IFS=',' read -r mod key action command <<< "$line"
        
        # Clean up spaces
        mod=$(echo "$mod" | xargs)
        key=$(echo "$key" | xargs)
        action=$(echo "$action" | xargs)
        command=$(echo "$command" | xargs)
        
        # Format the key combination
        if [[ "$mod" == "$main_mod" ]]; then
            keybind="$main_mod + $key"
        else
            keybind="$mod + $key"
        fi
        
        # Output for rofi
        echo "$keybind: $action $command"
    done
}

# Generate the list and show with rofi
parse_keybinds "$CONFIG_FILE" | rofi -dmenu -i -p "Hyprland Keybinds"