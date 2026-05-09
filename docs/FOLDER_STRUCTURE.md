# Estructura y Módulos

Este documento concentra el detalle de los módulos y la estructura real del proyecto.

## Módulos

| Módulo | Archivo | Qué hace | Política de errores |
|---|---|---|---|
| `apt` | `lib/apt.sh` | `apt update/upgrade`, `autoremove`, limpieza de caché de paquetes | Crítica: detiene ejecución si falla |
| `cleanup` | `lib/cleanup.sh` | Limpieza general de logs, `/tmp`, cachés de usuario y tareas complementarias | Tolerable: registra y continúa |
| `integrity` | `lib/integrity.sh` | Reparación/verificación de paquetes (`dpkg`, `debsums`, auditorías) | Mixta |
| `disk` | `lib/disk.sh` | Tareas de mantenimiento de disco (`fsck`, `btrfs scrub`, `xfs_repair`) | Tolerable |
| `dev` | `lib/dev/mod.sh` + `lib/dev/*.sh` | Limpieza de entorno de desarrollo (Docker, virtualización, IDEs, package managers, bases de datos) | Tolerable |

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
