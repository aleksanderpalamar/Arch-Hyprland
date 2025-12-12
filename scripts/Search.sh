#!/bin/bash

config_file=$HOME/.config/hypr/UserConfigs/UserDefaults.conf

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

get_config() {
    local var_name="$1"
    grep "^\s*\$$var_name\s*=" "$config_file" | sed 's/^.*=//;s/#.*//' | xargs | sed 's/^"//;s/"$//'
}

Search_Engine=$(get_config "Search_Engine")

if [[ -z "$Search_Engine" ]]; then
    Search_Engine="https://duckduckgo.com/?q={}"
fi

rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='**note** search via default web browser'

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
    sleep 0.1
fi

query=$(echo "" | rofi -dmenu -config "$rofi_theme" -mesg "$msg")

hyprctl dispatch focuscurrentorlast

if [[ -n "$query" ]]; then
    xdg-open "${Search_Engine/\{\}/$query}"
fi
