#!/bin/bash

# SwayNC Installation and Configuration Script
# Instala e configura o SwayNC (Sway Notification Center)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios
SWAYNC_CONFIG_DIR="$HOME/.config/swaync"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== SwayNC Installation ===${NC}\n"

# 1. Verificar se swaync está instalado
echo -e "${YELLOW}[1/4]${NC} Verificando instalação do SwayNC..."

if ! command -v swaync &> /dev/null; then
    echo -e "${RED}✗ SwayNC não está instalado${NC}"
    echo -e "${YELLOW}Instale com:${NC}"
    echo "  sudo pacman -S swaync"
    exit 1
else
    echo -e "${GREEN}✓ SwayNC está instalado${NC}"
    SWAYNC_VERSION=$(swaync --version 2>/dev/null || echo "unknown")
    echo "  Versão: $SWAYNC_VERSION"
fi

# 2. Criar diretório de configuração
echo -e "\n${YELLOW}[2/4]${NC} Criando diretório de configuração..."

if [ ! -d "$SWAYNC_CONFIG_DIR" ]; then
    mkdir -p "$SWAYNC_CONFIG_DIR"
    echo -e "${GREEN}✓ Diretório criado: $SWAYNC_CONFIG_DIR${NC}"
else
    echo -e "${GREEN}✓ Diretório já existe: $SWAYNC_CONFIG_DIR${NC}"
fi

# 3. Backup de configurações existentes
echo -e "\n${YELLOW}[3/4]${NC} Fazendo backup de configurações existentes..."

BACKUP_DIR="$SWAYNC_CONFIG_DIR/backup_$(date +%Y%m%d_%H%M%S)"

if [ -f "$SWAYNC_CONFIG_DIR/config.json" ] || [ -f "$SWAYNC_CONFIG_DIR/style.css" ]; then
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$SWAYNC_CONFIG_DIR/config.json" ]; then
        cp "$SWAYNC_CONFIG_DIR/config.json" "$BACKUP_DIR/"
        echo -e "${GREEN}✓ Backup de config.json${NC}"
    fi
    
    if [ -f "$SWAYNC_CONFIG_DIR/style.css" ]; then
        cp "$SWAYNC_CONFIG_DIR/style.css" "$BACKUP_DIR/"
        echo -e "${GREEN}✓ Backup de style.css${NC}"
    fi
    
    echo "  Backup salvo em: $BACKUP_DIR"
else
    echo -e "${GREEN}✓ Nenhuma configuração anterior encontrada${NC}"
fi

# 4. Copiar configurações padrão
echo -e "\n${YELLOW}[4/4]${NC} Instalando configurações padrão..."

if [ -f "$SCRIPT_DIR/config.json" ]; then
    cp "$SCRIPT_DIR/config.json" "$SWAYNC_CONFIG_DIR/"
    echo -e "${GREEN}✓ config.json instalado${NC}"
else
    echo -e "${RED}✗ config.json não encontrado em $SCRIPT_DIR${NC}"
fi

if [ -f "$SCRIPT_DIR/style.css" ]; then
    cp "$SCRIPT_DIR/style.css" "$SWAYNC_CONFIG_DIR/"
    echo -e "${GREEN}✓ style.css instalado${NC}"
else
    echo -e "${RED}✗ style.css não encontrado em $SCRIPT_DIR${NC}"
fi

# 5. Reiniciar o daemon
echo -e "\n${YELLOW}Reiniciando o daemon do SwayNC...${NC}"

if pgrep -x swaync > /dev/null; then
    killall swaync 2>/dev/null || true
    sleep 1
fi

swaync &
sleep 1

echo -e "${GREEN}✓ SwayNC reiniciado${NC}"

# 6. Summary
echo -e "\n${GREEN}=== Instalação Concluída ===${NC}\n"
echo -e "📍 Localização de configuração:"
echo "  $SWAYNC_CONFIG_DIR"
echo -e "\n📝 Arquivos instalados:"
echo "  - config.json (comportamento)"
echo "  - style.css (aparência)"
echo -e "\n🔧 Próximos passos:"
echo "  1. Edite os arquivos conforme necessário:"
echo "     nano ~/.config/swaync/config.json"
echo "     nano ~/.config/swaync/style.css"
echo -e "\n  2. Recarregue as configurações:"
echo "     swaync-client -R"
echo -e "\n  3. Para testar notificações:"
echo "     notify-send 'Título' 'Mensagem de teste'"
echo -e "\n📚 Documentação:"
echo "  Ver SWAYNC_CUSTOMIZATION.md para mais opções"
echo -e "\n"
