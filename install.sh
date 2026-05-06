#!/bin/bash

# =============================================================
#  install.sh — instalación del proyecto
#  Crea symlink en /usr/local/bin
#  Uso: sudo bash install.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYMLINK_TARGET="/usr/local/bin/mantenimiento-ubuntu"

if [[ $EUID -ne 0 ]]; then
    echo "Ejecutar como root: sudo bash install.sh"
    exit 1
fi

# Permisos correctos
chmod +x "${SCRIPT_DIR}/bin/mantenimiento.sh"

# Symlink
if [[ -L "$SYMLINK_TARGET" ]]; then
    rm "$SYMLINK_TARGET"
fi
ln -s "${SCRIPT_DIR}/bin/mantenimiento.sh" "$SYMLINK_TARGET"
echo "✔ Symlink creado: $SYMLINK_TARGET"

# Crear directorios de estado y logs si no existen
mkdir -p "${SCRIPT_DIR}/state" "${SCRIPT_DIR}/logs"
echo "✔ Directorios state/ y logs/ listos"

echo ""
echo "Instalación completa."
echo "Usá 'sudo mantenimiento-ubuntu --help' para ver las opciones."