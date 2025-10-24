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
    
    # Copia os arquivos da nova estrutura modular
    cp -r "$SRCDIR/components/hyprland/"*.conf "$HOME/.config/hypr/" 2>/dev/null || true
    cp -r "$SRCDIR/components/hyprland/UserConfigs" "$HOME/.config/hypr/" 2>/dev/null || true
    cp -r "$SRCDIR/scripts/"*.sh "$HOME/.config/hypr/scripts/" 2>/dev/null || true
    
    cp -r "$SRCDIR/components/rofi/"*.rasi "$HOME/.config/rofi/" 2>/dev/null || true
    cp -r "$SRCDIR/components/rofi/wallust" "$HOME/.config/rofi/" 2>/dev/null || true
    
    cp -r "$SRCDIR/components/waybar/config.jsonc" "$HOME/.config/waybar/" 2>/dev/null || true
    cp -r "$SRCDIR/components/waybar/style.css" "$HOME/.config/waybar/" 2>/dev/null || true
    cp -r "$SRCDIR/components/waybar/Modules"* "$HOME/.config/waybar/" 2>/dev/null || true
    
    cp -r "$SRCDIR/components/wallpaper/"*.{jpg,jpeg,png} "$HOME/Imagens/wallpapers/" 2>/dev/null || true
}

# Função para definir permissões de execução para os scripts
_set_permissions() {
    _print "Definindo permissões de execução para os scripts..."
    mkdir -p "$HOME/.config/hypr/scripts"
    chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
    
    # Define permissões para scripts do sistema também
    chmod +x "$SRCDIR/scripts/"*.sh 2>/dev/null || true
    chmod +x "$SRCDIR/tools/"*.sh 2>/dev/null || true
    chmod +x "$SRCDIR/services/"*.sh 2>/dev/null || true
}

# Função para inicializar o sistema modular
_initialize_system() {
    _print "Inicializando sistema modular..."
    SRCDIR=$(pwd)
    
    # Executa o controlador do sistema se existir
    if [ -f "$SRCDIR/tools/system-controller.sh" ]; then
        _print "Executando controlador do sistema..."
        bash "$SRCDIR/tools/system-controller.sh" --init
    fi
    
    # Analisa configurações se necessário
    if [ -f "$SRCDIR/tools/config-analyzer.sh" ]; then
        _print "Analisando configurações..."
        bash "$SRCDIR/tools/config-analyzer.sh" --install-check
    fi
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
    _initialize_system
    
    _print "------------------------------------------------------"
    _print "Instalação concluída com sucesso!"
    _print "Sistema modular inicializado e configurações geradas!"
    _warn "É recomendado reiniciar o sistema para que todas as alterações tenham efeito."
    _print "------------------------------------------------------"
}

# Executa a função principal
main