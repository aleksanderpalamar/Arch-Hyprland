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
    
    # Copia os arquivos da estrutura core (configurações principais)
    cp -r "$SRCDIR/core/hypr/"*.conf "$HOME/.config/hypr/" 2>/dev/null || true
    
    # Copia UserConfigs (prioriza core, depois components)
    if [ -d "$SRCDIR/core/hypr/UserConfigs" ]; then
        cp -r "$SRCDIR/core/hypr/UserConfigs" "$HOME/.config/hypr/" 2>/dev/null || true
    elif [ -d "$SRCDIR/components/hyprland/UserConfigs" ]; then
        cp -r "$SRCDIR/components/hyprland/UserConfigs" "$HOME/.config/hypr/" 2>/dev/null || true
    fi
    
    # Copia scripts
    mkdir -p "$HOME/.config/hypr/scripts"
    cp -r "$SRCDIR/scripts/"*.sh "$HOME/.config/hypr/scripts/" 2>/dev/null || true
    
    # Copia configurações do Rofi
    cp -r "$SRCDIR/components/rofi/"*.rasi "$HOME/.config/rofi/" 2>/dev/null || true
    if [ -d "$SRCDIR/components/rofi/wallust" ]; then
        cp -r "$SRCDIR/components/rofi/wallust" "$HOME/.config/rofi/" 2>/dev/null || true
    fi
    
    # Copia configurações do Waybar 
    cp "$SRCDIR/components/waybar/config.jsonc" "$HOME/.config/waybar/" 2>/dev/null || true
    cp "$SRCDIR/components/waybar/style.css" "$HOME/.config/waybar/" 2>/dev/null || true
    cp "$SRCDIR/components/waybar/Modules"* "$HOME/.config/waybar/" 2>/dev/null || true
    
    # Copia wallpapers
    for ext in jpg jpeg png; do
        cp "$SRCDIR/components/wallpaper/"*.$ext "$HOME/Imagens/wallpapers/" 2>/dev/null || true
    done
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

# Função para corrigir configurações desatualizadas
_fix_deprecated_configs() {
    _print "Removendo configurações problemáticas..."
    
    # Remove qualquer configuração de gestos que cause problemas
    local input_conf="$HOME/.config/hypr/UserConfigs/UserInput.conf"
    if [ -f "$input_conf" ]; then
        _warn "Removendo configurações de gestos problemáticas"
        # Remove toda a seção gestures que causa problemas
        sed -i '/^gestures {$/,/^}$/d' "$input_conf"
        # Adiciona comentário explicativo
        echo "" >> "$input_conf"
        echo "# Gestures configuration disabled due to compatibility issues" >> "$input_conf"
        echo "# Enable manually if needed for your Hyprland version" >> "$input_conf"
    fi
}

# Função para inicializar o sistema modular
_initialize_system() {
    _print "Inicializando sistema modular..."
    SRCDIR=$(pwd)
    
    # Verifica se as configurações foram copiadas corretamente
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
    
    # Corrige configurações desatualizadas
    _fix_deprecated_configs
    
    _print "Sistema básico configurado e pronto para uso"
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