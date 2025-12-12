#!/bin/bash

WALLPAPER_DIR="$HOME/Imagens/wallpapers"

if ! pgrep -x "hyprpaper" > /dev/null;
then
    hyprpaper &
    sleep 0.5
fi

if [ ! -d "$WALLPAPER_DIR" ]; then
  notify-send "Erro" "Diretório de wallpapers não encontrado em $WALLPAPER_DIR"
  exit 1
fi

cd "$WALLPAPER_DIR"

selected_wallpaper=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -printf "%T@ %f\n" | sort -nr | cut -d' ' -f2- | rofi -dmenu -i -p "󰸉 Escolha o Wallpaper (mais novos primeiro)")

if [ -n "$selected_wallpaper" ]; then
  full_path="$WALLPAPER_DIR/$selected_wallpaper"
  
  config_path="~/Imagens/wallpapers/$selected_wallpaper"

  hyprctl hyprpaper unload all
  hyprctl hyprpaper preload "$full_path"
  hyprctl hyprpaper wallpaper ",$full_path"
  
  sed -i "s#^preload = .*#preload = $config_path#" "$HOME/.config/hypr/hyprpaper.conf"
  sed -i "s#^wallpaper = .*#wallpaper = ,$config_path#" "$HOME/.config/hypr/hyprpaper.conf"

  notify-send "Wallpaper Alterado" "Definido como $selected_wallpaper" -i "$full_path"
fi
