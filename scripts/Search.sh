#!/bin/bash

config_file=$HOME/.config/hypr/UserConfigs/UserDefaults.conf

if [[ ! -f "$config_file" ]]; then
  echo "Error: Configuration file not found!"
  exit 1
fi

config_content=$(sed 's/\$//g' "$config_file" | sed 's/ = /=/')

eval "$config_content"

if [[ -z "$Search_Engine" ]]; then
    echo "Error: \$Search_Engine is not set in the configuration file!"
    exit 1
fi

rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='**note** search via default web browser'

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

echo "" | rofi -dmenu -config "$rofi_theme" -mesg "$msg" | xargs -I{} xdg-open $Search_Engine
