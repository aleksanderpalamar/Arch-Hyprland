#!/bin/bash
set -e

GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

_print() {
    echo -e "${GREEN}󰔟  $1${RESET}"
}

_warn() {
    echo -e "${YELLOW}󰀪  $1${RESET}"
}

_check_aur_helper() {
    _print "Verificando a presença de um AUR helper (yay ou paru)..."
    if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
        _warn "Nenhum AUR helper encontrado. Por favor, instale 'yay' ou 'paru' para continuar."
        exit 1
    fi
    AUR_HELPER=$(command -v yay || command -v paru)
    _print "AUR helper encontrado: $AUR_HELPER"
}

_install_packages() {
    _print "Instalando pacotes dos repositórios oficiais..."
    
    local pkgs=(
        hyprland rofi-wayland kitty waybar hyprpaper hyprcursor swaync 
        thunar grim slurp swaylock pipewire wireplumber pipewire-pulse 
        pamixer pavucontrol brightnessctl playerctl nwg-displays jq
        noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome
        gnome-keyring libsecret polkit-gnome nautilus
    )
    
    sudo pacman -S --noconfirm --needed "${pkgs[@]}"
}

_install_aur_packages() {
    _print "Instalando pacotes do AUR..."
    
    local aur_pkgs=(
        wlogout wallust
    )
    
    $AUR_HELPER -S --noconfirm --needed "${aur_pkgs[@]}"
}

_check_install_extra() {
    read -p "Deseja instalar pacotes extras (git, fastfetch, htop, wget, curl)? (s/n): " Choice
    case "$Choice" in
        [Ss]* ) _install_extra_packages ;;
        * ) _print "Pulando instalação de pacotes extras." ;;
    esac
}

_install_extra_packages() {
    _print "Instalando pacotes extras..."
    
    local extra_pkgs=(
        git fastfetch htop wget curl
    )
    
    sudo pacman -S --noconfirm --needed "${extra_pkgs[@]}"
}

_backup_configs() {
    _print "Fazendo backup das configurações existentes..."
    BACKUP_DIR="$HOME/.config/hyprland-backup-$(date +%Y-%m-%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    _print "Diretório de backup criado em $BACKUP_DIR"
    
    [ -d "$HOME/.config/hypr" ] && mv "$HOME/.config/hypr" "$BACKUP_DIR/"
    [ -d "$HOME/.config/rofi" ] && mv "$HOME/.config/rofi" "$BACKUP_DIR/"
    [ -d "$HOME/.config/waybar" ] && mv "$HOME/.config/waybar" "$BACKUP_DIR/"
    [ -d "$HOME/.config/swaync" ] && mv "$HOME/.config/swaync" "$BACKUP_DIR/"
    [ -d "$HOME/.config/kitty" ] && mv "$HOME/.config/kitty" "$BACKUP_DIR/"
}

_copy_configs() {
    _print "Copiando novas configurações..."
    SRCDIR="$SCRIPT_DIR"
    
    mkdir -p "$HOME/.config/hypr"
    mkdir -p "$HOME/.config/hypr/scripts"
    mkdir -p "$HOME/.config/rofi"
    mkdir -p "$HOME/.config/waybar"
    mkdir -p "$HOME/.config/swaync"
    mkdir -p "$HOME/Imagens/wallpapers"
    mkdir -p "$HOME/.config/kitty"

    cp -r "$SRCDIR/components/kitty/"* "$HOME/.config/kitty/" 2>/dev/null || true
    
    cp -r "$SRCDIR/core/hypr/"*.conf "$HOME/.config/hypr/" 2>/dev/null || true

    cp -r "$SRCDIR/core/hypr/UserConfigs" "$HOME/.config/hypr/" 2>/dev/null || true    

    cp "$SRCDIR/scripts/"*.sh "$HOME/.config/hypr/scripts/" 2>/dev/null || true

    cp -r "$SRCDIR/components/rofi/"*.rasi "$HOME/.config/rofi/" 2>/dev/null || true
    cp -r "$SRCDIR/components/rofi/"*.conf "$HOME/.config/rofi/" 2>/dev/null || true
    if [ -d "$SRCDIR/components/rofi/wallust" ]; then
        cp -r "$SRCDIR/components/rofi/wallust" "$HOME/.config/rofi/" 2>/dev/null || true
    fi

    cp "$SRCDIR/components/waybar/config.jsonc" "$HOME/.config/waybar/" 2>/dev/null || true
    cp "$SRCDIR/components/waybar/style.css" "$HOME/.config/waybar/" 2>/dev/null || true
    cp "$SRCDIR/components/waybar/colors.css" "$HOME/.config/waybar/" 2>/dev/null || true
    cp -d "$SRCDIR/components/waybar/theme.css" "$HOME/.config/waybar/" 2>/dev/null || true
    cp "$SRCDIR/components/waybar/Modules"* "$HOME/.config/waybar/" 2>/dev/null || true

    mkdir -p "$HOME/.config/waybar/modules"
    cp "$SRCDIR/components/waybar/modules/"*.jsonc "$HOME/.config/waybar/modules/" 2>/dev/null || true

    mkdir -p "$HOME/.config/waybar/themes"
    cp "$SRCDIR/components/waybar/themes/"*.css "$HOME/.config/waybar/themes/" 2>/dev/null || true

    cp "$SRCDIR/components/swaync/config.json" "$HOME/.config/swaync/" 2>/dev/null || true
    cp "$SRCDIR/components/swaync/style.css" "$HOME/.config/swaync/" 2>/dev/null || true

    for ext in jpg jpeg png; do
        cp "$SRCDIR/components/wallpaper/"*.$ext "$HOME/Imagens/wallpapers/" 2>/dev/null || true
    done
}

_set_permissions() {
    _print "Definindo permissões de execução para os scripts..."
    chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/scripts/"*.py 2>/dev/null || true
    
    # Define permissões para scripts do sistema também
    chmod +x "$SRCDIR/scripts/"*.sh 2>/dev/null || true
    chmod +x "$SRCDIR/scripts/"*.py 2>/dev/null || true
    chmod +x "$SRCDIR/tools/"*.sh 2>/dev/null || true
    chmod +x "$SRCDIR/services/"*.sh 2>/dev/null || true
}

_fix_deprecated_configs() {
    _print "Removendo configurações problemáticas..."
    local input_conf="$HOME/.config/hypr/UserConfigs/UserInput.conf"
    if [ -f "$input_conf" ]; then
        _warn "Removendo configurações de gestos problemáticas"
        sed -i '/^gestures {$/,/^}$/d' "$input_conf"
        echo "" >> "$input_conf"
        echo "# Gestures configuration disabled due to compatibility issues" >> "$input_conf"
        echo "# Enable manually if needed for your Hyprland version" >> "$input_conf"
    fi
}

_initialize_system() {
    _print "Inicializando sistema modular..."
    SRCDIR="$SCRIPT_DIR"

    if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
        _print "✓ Configuração principal do Hyprland copiada"
    else
        _warn "✗ Erro ao copiar configuração principal do Hyprland"
    fi
    
    if [ -d "$HOME/.config/hypr/UserConfigs" ]; then
        _print "✓ UserConfigs copiados com sucesso"
    else
        _warn "✗ Erro ao copiar UserConfigs"
    fi
    
    if [ -d "$HOME/.config/hypr/scripts" ]; then
        _print "✓ Scripts copiados e permissões definidas"
    else
        _warn "✗ Erro ao copiar scripts"
    fi

    _fix_deprecated_configs
    
    _print "Sistema básico configurado e pronto para uso"
}

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

main