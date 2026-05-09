# mantenimiento-ubuntu

Equivalente a `cleanmgr` + `sfc /scannow` de Windows para Ubuntu/Debian.
Diseñado para desktop y entornos de desarrollo. No es un reemplazo directo para servidores de producción (ver notas internas en cada módulo).

## Instalación

```bash
sudo bash install.sh
```

## Uso

```bash
# Ejecución normal
sudo mantenimiento-ubuntu

# Simular sin modificar nada (recomendado antes de la primera ejecución)
sudo mantenimiento-ubuntu --dry-run

# Ejecutar solo algunos módulos
sudo mantenimiento-ubuntu --only=apt,cleanup

# Omitir un módulo
sudo mantenimiento-ubuntu --skip=disk

# Ayuda
sudo mantenimiento-ubuntu --help
```

## Módulos

- `apt`: mantenimiento de paquetes APT (crítico).
- `cleanup`: limpieza general de sistema y cachés (tolerable).
- `integrity`: validación/reparación de integridad de paquetes (mixta).
- `disk`: tareas de mantenimiento de disco (tolerable).
- `dev`: limpieza de entorno de desarrollo, dividida en submódulos (tolerable).

Detalle completo en [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md).

## Configuración

Los valores por defecto están en `config/default.conf` (versionado, no editar).
Para personalizar, editá `config/user.conf` (en `.gitignore`):

```bash
cp config/user.conf.example config/user.conf   # si existe
# o simplemente crear el archivo con las variables a sobrescribir
```

### Variables disponibles

| Variable | Default | Descripción |
|---|---|---|
| `LOG_DAYS` | `7` | Días de logs de systemd a conservar |
| `TMP_DAYS` | `1` | Antigüedad mínima (mtime) para limpiar `/tmp` |
| `CACHE_DAYS` | `30` | Antigüedad mínima de caché de usuario |
| `ENABLE_SNAP_CLEANUP` | `true` | Eliminar versiones antiguas de snap |
| `ENABLE_FSCK` | `true` | Programar chequeo de disco |
| `ENABLE_DEBSUMS` | `true` | Verificar integridad con debsums |
| `ENABLE_LOGROTATE` | `false` | Usar logrotate en vez de solo journalctl |
| `CACHE_EXCLUDE_PATHS` | navegadores | Rutas relativas a `~/.cache/` que no se tocan |
| `SCRIPT_LOG_KEEP_DAYS` | `30` | Días de logs del propio script a conservar |

## Estructura

Resumen:

- `bin/`: entrypoint y orquestación.
- `lib/`: módulos funcionales y utilidades comunes.
- `lib/dev/`: submódulos del entorno de desarrollo.
- `config/`: configuración por defecto.
- `state/`: estado de última ejecución.
- `logs/`: logs de ejecución.

Estructura detallada y actualizada en [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md).