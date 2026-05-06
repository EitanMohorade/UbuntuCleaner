#!/bin/bash

set -e

echo "==== INICIO DE MANTENIMIENTO ===="

# 1. Actualizar lista de paquetes
echo "[1/8] Actualizando repositorios..."
sudo apt update

# 2. Actualizar sistema
echo "[2/8] Actualizando paquetes instalados..."
sudo apt upgrade -y

# 3. Eliminar paquetes innecesarios
echo "[3/8] Eliminando dependencias no utilizadas..."
sudo apt autoremove -y

# 4. Limpiar cache de paquetes
echo "[4/8] Limpiando cache de APT..."
sudo apt clean

# 5. Limpiar cache residual
echo "[5/8] Limpiando cache obsoleta..."
sudo apt autoclean

# 6. Limpiar logs antiguos (más de 7 días)
echo "[6/8] Limpiando logs del sistema..."
sudo journalctl --vacuum-time=7d

# 7. Verificación de integridad de paquetes (equivalente parcial a sfc)
echo "[7/8] Verificando integridad de paquetes..."
sudo debsums -s || true

# 8. Chequeo del sistema de archivos (solo si reinicio programado)
echo "[8/8] Programando chequeo de disco en próximo reinicio..."
sudo touch /forcefsck

echo "==== FIN DE MANTENIMIENTO ===="