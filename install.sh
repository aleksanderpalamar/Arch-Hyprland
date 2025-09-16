#!/bin/bash

# ------------------------------------------------------
# Script de Instalação do Hyprland e Dotfiles
# ------------------------------------------------------

# Cores para as mensagens
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Função para imprimir mensagens formatadas
_print() {
    echo -e "${GREEN}󰔟  $1${RESET}"
}

# Função para imprimir avisos
_warn() {
    echo -e "${YELLOW}󰀪  $1${RESET}"
}

# Verifica se o AUR helper (yay ou paru) está instalado
_check_aur_helper() {
    _print "Verificando a presença de um AUR helper (yay ou paru)..."
    if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
        _warn "Nenhum AUR helper encontrado. Por favor, instale 'yay' ou 'paru' para continuar."
        exit 1
    fi
    AUR_HELPER=$(command -v yay || command -v paru)
    _print "AUR helper encontrado: $AUR_HELPER"
}

# Função para instalar pacotes dos repositórios oficiais
_install_packages() {
    _print "Instalando pacotes dos repositórios oficiais..."
    
    local pkgs=(
        hyprland rofi-wayland kitty waybar hyprpaper hyprcursor swaync 
        thunar grim slurp swaylock pipewire wireplumber pipewire-pulse 
        pamixer pavucontrol brightnessctl playerctl nwg-displays jq
        noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome
    )
    
    sudo pacman -S --noconfirm --needed "${pkgs[@]}"
}

# Função para instalar pacotes do AUR
_install_aur_packages() {
    _print "Instalando pacotes do AUR..."
    
    local aur_pkgs=(
        wlogout wallust
    )
    
    $AUR_HELPER -S --noconfirm --needed "${aur_pkgs[@]}"
}

# Função para fazer backup das configurações existentes
_backup_configs() {
    _print "Fazendo backup das configurações existentes..."
    BACKUP_DIR="$HOME/.config/hyprland-backup-$(date +%Y-%m-%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    _print "Diretório de backup criado em $BACKUP_DIR"
    
    [ -d "$HOME/.config/hypr" ] && mv "$HOME/.config/hypr" "$BACKUP_DIR/"
    [ -d "$HOME/.config/rofi" ] && mv "$HOME/.config/rofi" "$BACKUP_DIR/"
    [ -d "$HOME/.config/waybar" ] && mv "$HOME/.config/waybar" "$BACKUP_DIR/"
}

# Função para copiar as novas configurações
_copy_configs() {
    _print "Copiando novas configurações..."
    SRCDIR=$(pwd)
    
    # Cria os diretórios de configuração
    mkdir -p "$HOME/.config/hypr"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/waybar"
    mkdir -p "$HOME/Imagens/wallpapers"
    
    # Copia os arquivos
    cp -r "$SRCDIR/hypr/"* "$HOME/.config/hypr/"
    cp -r "$SRCDIR/rofi/"* "$HOME/.config/rofi/"
    cp -r "$SRCDIR/waybar/"* "$HOME/.config/waybar/"
    cp -r "$SRCDIR/wallpaper/"* "$HOME/Imagens/wallpapers/"
}

# Função para definir permissões de execução para os scripts
_set_permissions() {
    _print "Definindo permissões de execução para os scripts..."
    chmod +x "$HOME/.config/hypr/scripts/"*.sh
}

# Função principal
main() {
    _print "Iniciando a instalação do ambiente Hyprland..."
    
    _check_aur_helper
    _install_packages
    _install_aur_packages
    _backup_configs
    _copy_configs
    _set_permissions
    
    _print "------------------------------------------------------"
    _print "Instalação concluída com sucesso!"
    _warn "É recomendado reiniciar o sistema para que todas as alterações tenham efeito."
    _print "------------------------------------------------------"
}

# Executa a função principal
main