#!/bin/bash

# Script para iniciar Waybar com configurações corretas do Wayland
# Localização: ~/.config/hypr/scripts/WaybarStart.sh

# Define variáveis de ambiente para Wayland
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland

# Para qualquer instância da Waybar que esteja rodando
pkill waybar 2>/dev/null

# Aguarda um momento para garantir que parou
sleep 1

# Inicia Waybar
waybar > /tmp/waybar.log 2>&1 &

# Log de inicialização
echo "$(date): Waybar iniciada com variáveis Wayland configuradas" >> /tmp/waybar-start.log