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

| Módulo | Qué hace | Política de errores |
|---|---|---|
| `apt` | update, upgrade, autoremove, clean | Crítica — detiene el script si falla |
| `cleanup` | logs, /tmp, caché de usuarios, snap | Tolerable — registra y continúa |
| `integrity` | dpkg repair (crítico), audit + debsums (tolerable) | Mixta |
| `disk` | Programa fsck, btrfs scrub, o xfs_repair | Tolerable |

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

```
mantenimiento-ubuntu/
├── bin/
│   └── mantenimiento.sh      # entrypoint: args, orquestación, resumen
├── lib/
│   ├── core.sh               # logging, run_tolerant, maybe_run, get_used_mb
│   ├── config.sh             # carga y validación de configuración
│   ├── apt.sh                # módulo APT (crítico)
│   ├── cleanup.sh            # módulo limpieza (tolerable)
│   ├── integrity.sh          # módulo integridad (mixto)
│   └── disk.sh               # módulo disco (tolerable)
├── config/
│   ├── default.conf          # valores por defecto (versionado)
│   └── user.conf             # overrides personales (gitignored)
├── state/
│   └── last_run.json         # métricas de la última ejecución
├── logs/
│   └── YYYY-MM.log           # logs del script, rotados mensualmente
├── install.sh                # instalación y cron opcional
├── .gitignore
└── README.md
```