#!/bin/bash

# --- Script para Seleção de Wallpaper com Rofi ---

# Diretório dos wallpapers
WALLPAPER_DIR="$HOME/Imagens/wallpapers"

# --- Correção de Robustez ---
# Verifica se o hyprpaper está em execução. Se não estiver, inicia-o.
if ! pgrep -x "hyprpaper" > /dev/null;
then
    hyprpaper &
    sleep 0.5 # Dá um pequeno tempo para o processo iniciar
fi
# --- Fim da Correção ---

# Verifica se o diretório existe
if [ ! -d "$WALLPAPER_DIR" ]; then
  notify-send "Erro" "Diretório de wallpapers não encontrado em $WALLPAPER_DIR"
  exit 1
fi

# Navega para o diretório para simplificar os nomes dos arquivos
cd "$WALLPAPER_DIR"

# Gera a lista de arquivos de imagem, ordenando pelos mais recentes primeiro,
# e exibe no Rofi.
selected_wallpaper=$(find . -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -printf "%T@ %f\n" | sort -nr | cut -d' ' -f2- | rofi -dmenu -i -p "󰸉 Escolha o Wallpaper (mais novos primeiro)")

# Se um wallpaper foi selecionado (o usuário não cancelou)
if [ -n "$selected_wallpaper" ]; then
  # Caminho completo para o wallpaper selecionado
  full_path="$WALLPAPER_DIR/$selected_wallpaper"
  
  # Caminho para usar no arquivo de configuração (com ~ para portabilidade)
  config_path="~/Imagens/wallpapers/$selected_wallpaper"

  # Usa hyprctl para trocar o wallpaper de forma eficiente
  hyprctl hyprpaper unload all
  hyprctl hyprpaper preload "$full_path"
  hyprctl hyprpaper wallpaper ",$full_path"
  
  # Atualiza o hyprpaper.conf para tornar a escolha persistente
  # Usamos # como delimitador no sed para evitar conflitos com as barras do caminho
  sed -i "s#^preload = .*#preload = $config_path#" "$HOME/.config/hypr/hyprpaper.conf"
  sed -i "s#^wallpaper = .*#wallpaper = ,$config_path#" "$HOME/.config/hypr/hyprpaper.conf"

  # Envia uma notificação para confirmar a troca
  notify-send "Wallpaper Alterado" "Definido como $selected_wallpaper" -i "$full_path"
fi
