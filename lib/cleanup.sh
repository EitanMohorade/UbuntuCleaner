#!/bin/bash
# Limpieza de archivos no critica: registra errores y continua.

run_cleanup() {
    step "CLEANUP" "Limpieza de archivos"

    _cleanup_logs
    _cleanup_tmp
    _cleanup_users
    [[ "${ENABLE_SNAP_CLEANUP:-true}" == true ]] && _cleanup_snap || true
}

_cleanup_logs() {
    info "Limpiando logs del sistema (retención: ${LOG_DAYS} días)..."

    # Usa journalctl como estrategia de limpieza por defecto.
    run_tolerant "journalctl vacuum" \
        journalctl --vacuum-time="${LOG_DAYS}d"

    ok "Logs de systemd depurados"
}

_cleanup_tmp() {
    info "Limpiando /tmp (archivos regulares >$TMP_DAYS día(s), no abiertos)..."

    # Proteccion: solo archivos regulares, por mtime y sin uso activo.

    local tmp_borrados=0

    if [[ "${DRY_RUN:-false}" == true ]]; then
        tmp_borrados=$(find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" 2>/dev/null | wc -l)
        info "  [DRY-RUN] Se eliminarían ${tmp_borrados} archivo(s) de /tmp"
        return 0
    fi

    if command -v fuser &>/dev/null; then
        while IFS= read -r f; do
            if ! fuser "$f" &>/dev/null 2>&1; then
                rm -f "$f" 2>/dev/null && (( tmp_borrados++ )) || true
            else
                info "  /tmp: en uso, omitido → $(basename "$f")"
            fi
        done < <(find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" 2>/dev/null)
    else
        warn "fuser no disponible (instalar psmisc); limpieza sin verificación de uso"
        tmp_borrados=$(find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" 2>/dev/null | wc -l)
        find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" -delete 2>/dev/null || true
    fi

    ok "/tmp: ${tmp_borrados} archivo(s) eliminado(s)"

    if [[ -d /var/crash ]]; then
        run_tolerant "limpiar /var/crash" bash -c 'rm -f /var/crash/*'
        ok "Reportes de crash eliminados"
    fi
}

_cleanup_users() {
    info "Limpiando caché y miniaturas de usuarios (retención: ${CACHE_DAYS} días)..."

    # Usa mtime y excluye rutas definidas en CACHE_EXCLUDE_PATHS.

    for home_dir in /home/*/; do
        [[ -d "$home_dir" ]] || continue
        local usuario; usuario=$(basename "$home_dir")

        # Miniaturas.
        if [[ -d "${home_dir}.cache/thumbnails" ]]; then
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local n; n=$(find "${home_dir}.cache/thumbnails" -type f \
                    -mtime +"$CACHE_DAYS" 2>/dev/null | wc -l)
                info "  [DRY-RUN] $usuario: ${n} miniatura(s) a eliminar"
            else
                find "${home_dir}.cache/thumbnails" -type f \
                    -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                info "  Miniaturas de '$usuario' (>${CACHE_DAYS}d mtime) eliminadas"
            fi
        fi

        # Papelera.
        if [[ -d "${home_dir}.local/share/Trash" ]]; then
            run_tolerant "papelera de $usuario" bash -c \
                "rm -rf '${home_dir}.local/share/Trash/files/'* \
                        '${home_dir}.local/share/Trash/info/'*"
            info "  Papelera de '$usuario' vaciada"
        fi

        # Cache general con exclusiones definidas en config.
        if [[ -d "${home_dir}.cache" ]]; then
            local find_cmd=(find "${home_dir}.cache"
                -mindepth 1 -maxdepth 3
                -type f
                -mtime +"$CACHE_DAYS"
            )
            for excl in ${CACHE_EXCLUDE_PATHS:-}; do
                find_cmd+=(-not -path "${home_dir}${excl}/*")
            done

            if [[ "${DRY_RUN:-false}" == true ]]; then
                local n; n=$("${find_cmd[@]}" 2>/dev/null | wc -l)
                info "  [DRY-RUN] $usuario: ${n} archivo(s) de caché a eliminar"
            else
                find_cmd+=(-delete)
                "${find_cmd[@]}" 2>/dev/null || true
            fi
        fi
    done

    ok "Caché de usuarios procesada"
}

_cleanup_snap() {
    if ! command -v snap &>/dev/null; then
        info "Snap no instalado, paso omitido"
        return 0
    fi

    info "Limpiando versiones antiguas de Snap..."

    snap list --all 2>/dev/null \
        | awk '/disabled/ {print $1, $3}' \
        | while read -r snap_name revision; do
            run_tolerant "snap remove $snap_name rev.$revision" \
                snap remove "$snap_name" --revision="$revision"
            info "  Snap eliminado: $snap_name rev.$revision"
          done

    ok "Versiones antiguas de Snap eliminadas"
}
