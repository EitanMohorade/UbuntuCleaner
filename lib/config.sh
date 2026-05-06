#!/bin/bash
# lib/config.sh — carga y validación de configuración
# Sourced después de core.sh; no ejecuta nada al cargar.

load_config() {
    local root_dir="$1"
    local default_conf="${root_dir}/config/default.conf"
    local user_conf="${root_dir}/config/user.conf"

    # 1. Cargar valores por defecto (siempre requerido)
    if [[ ! -f "$default_conf" ]]; then
        err "Archivo de config no encontrado: $default_conf"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$default_conf"

    # 2. Si existe user.conf, sus valores sobreescriben los defaults
    if [[ -f "$user_conf" ]]; then
        # shellcheck source=/dev/null
        source "$user_conf"
        info "Configuración de usuario cargada: $user_conf"
    fi
}

validate_config() {
    local errors=0

    # Verificar que las variables requeridas sean enteros positivos
    for var in LOG_DAYS TMP_DAYS CACHE_DAYS SCRIPT_LOG_KEEP_DAYS; do
        local val="${!var:-}"
        if [[ -z "$val" ]] || ! [[ "$val" =~ ^[0-9]+$ ]] || (( val < 1 )); then
            err "Config inválida: $var='${val}' (debe ser entero positivo)"
            (( errors++ )) || true
        fi
    done

    # Verificar booleanos
    for var in ENABLE_SNAP_CLEANUP ENABLE_FSCK ENABLE_DEBSUMS ENABLE_LOGROTATE; do
        local val="${!var:-}"
        if [[ "$val" != "true" && "$val" != "false" ]]; then
            err "Config inválida: $var='${val}' (debe ser true o false)"
            (( errors++ )) || true
        fi
    done

    if (( errors > 0 )); then
        err "${errors} error(es) en la configuración. Revisá config/default.conf o config/user.conf"
        exit 1
    fi
}
