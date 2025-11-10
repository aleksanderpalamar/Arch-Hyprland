#!/usr/bin/env bash

# Script wrapper para executar ia_chat_hypr.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IA_SCRIPT="$SCRIPT_DIR/ia_chat_hypr.py"

# Verificar se o script existe
if [ ! -f "$IA_SCRIPT" ]; then
    echo "Erro: $IA_SCRIPT não encontrado!"
    exit 1
fi

# Verificar se as dependências estão instaladas
if ! python -c "import PyQt5, requests, dotenv" 2>/dev/null; then
    echo "⚠️  Instalando dependências Python..."
    pip install --user --break-system-packages requests python-dotenv PyQt5 2>/dev/null || \
    pip install --user requests python-dotenv PyQt5
fi

# Executar o script Python
exec python "$IA_SCRIPT" "$@"

