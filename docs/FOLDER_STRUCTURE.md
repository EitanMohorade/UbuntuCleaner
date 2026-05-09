# Estructura y Módulos

Este documento concentra el detalle de los módulos y la estructura real del proyecto.

## Módulos

| Módulo | Archivo | Qué hace | Reportes | Política de errores |
|---|---|---|---|---|
| `apt` | `lib/apt.sh` | `apt update/upgrade`, `autoremove`, limpieza de caché; detecta paquetes realmente actualizados | Nº paquetes, bytes liberados | Crítica: detiene ejecución si falla |
| `cleanup` | `lib/cleanup.sh` | Limpieza de journal, `/tmp`, cachés de usuario, caché apt, snap; mide bytes liberados x acción | Bytes x acción | Tolerable: registra y continúa |
| `integrity` | `lib/integrity.sh` | Reparación/verificación de paquetes (`dpkg`, `debsums`, auditorías) | OK/WARN/ERROR | Mixta |
| `disk` | `lib/disk.sh` | Tareas de mantenimiento de disco (`fsck`, `btrfs scrub`, `xfs_repair`) | OK/SKIP | Tolerable |
| `dev` | `lib/dev/mod.sh` + `lib/dev/*.sh` | Limpieza de Docker, libvirt, VirtualBox, IDEs, npm/pip/gradle/maven, logs de BD | OK/SKIP x submódulo | Tolerable |

## Estructura

```text
UbuntuCleaner/
├── bin/
│   └── mantenimiento.sh      # entrypoint: argumentos, orquestación, resumen
├── config/
│   └── default.conf          # valores por defecto (versionado)
├── lib/
│   ├── apt.sh                # módulo apt
│   ├── cleanup.sh            # módulo cleanup
│   ├── config.sh             # carga/validación de configuración
│   ├── core.sh               # utilidades comunes (log, wrappers, métricas)
│   ├── dev.sh                # loader de compatibilidad del módulo dev
│   ├── dev/
│   │   ├── common.sh         # utilidades compartidas del módulo dev
│   │   ├── databases.sh      # limpieza de logs de bases de datos
│   │   ├── docker.sh         # limpieza de Docker
│   │   ├── ides.sh           # limpieza de IDEs
│   │   ├── mod.sh            # orquestador del módulo dev
│   │   ├── package_managers.sh # limpieza de npm/pip/gradle/maven
│   │   └── virtualization.sh  # limpieza de libvirt/VirtualBox
│   ├── disk.sh               # módulo disk
│   └── integrity.sh          # módulo integrity
├── logs/                     # logs de ejecución
├── state/
│   └── last_run.json         # estado de última ejecución
├── .gitignore
├── install.sh                # instalación
├── README.md
└── FOLDER_STRUCTURE.md
```

## Reportes y Persistencia

Todos los eventos de ejecución se registran en `state/last_run.json`:

```json
{
  "timestamp": "2026-05-09T15:35:22+00:00",
  "dry_run": false,
  "space_before_bytes": 21995000000,
  "space_after_bytes": 21900000000,
  "space_freed_bytes": 95000000,
  "space_freed_human": "95.0 MB",
  "report_counts": {
    "ok": 12,
    "warn": 1,
    "error": 0,
    "timeout": 0,
    "skip": 3
  },
  "report_events": {
    "ok": [
      "journalctl vacuum: 50.2 MB liberados",
      "apt-get clean: 30.0 MB liberados",
      "apt: 5 paquete(s) actualizados",
      ...
    ],
    "warn": [...],
    "error": [...],
    "timeout": [...],
    "skip": [...]
  },
  "modules_run": ["apt", "cleanup", "integrity", "disk", "dev"],
  "warnings": [...]
}
```

### Eventos por módulo

#### `apt`
- ✓ `"apt: N paquete(s) actualizados"` (N > 0) — se aplicaron actualizaciones
- ⊘ `"apt: no había actualizaciones disponibles"` — no había pendientes
- ✓ `"apt: M bytes liberados tras actualización"` — se liberó espacio
- ⚠ `"apt: uso aumentado M bytes tras actualización"` — actualizaciones ocuparon más (puede ser normal)

#### `cleanup`
- ✓ `"journalctl vacuum: M bytes liberados"`
- ✓ `"apt-get clean: M bytes liberados"`
- ✓ `"snap cache: M bytes liberados"`
- ✓ `"/tmp: N archivo(s) eliminado(s)"`

#### `dev`
- ⊘ `"dev/docker: sin contenedores"`, `"dev/ides: sin IDEs detectados"`, etc.
- ✓ `"dev/docker: contenedor(es) limpio(s)"`, `"dev/package-managers: limpieza completada"`
