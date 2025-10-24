#!/bin/bash

# Script Bridge - Redirecionador de scripts legados para modulares
# Permite que scripts antigos funcionem com a nova estrutura

LEGACY_SCRIPT_NAME="$(basename "$0")"
MODULAR_SCRIPT_PATH="./tools/../components/scripts/$LEGACY_SCRIPT_NAME"

if [ -f "$MODULAR_SCRIPT_PATH" ]; then
    echo "Redirecionando para script modular: $LEGACY_SCRIPT_NAME" >&2
    exec "$MODULAR_SCRIPT_PATH" "$@"
else
    echo "Script não encontrado na estrutura modular: $LEGACY_SCRIPT_NAME" >&2
    exit 1
fi
