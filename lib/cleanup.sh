#!/bin/bash
# Limpieza de archivos tolerante a fallos.

run_cleanup() {
    step "CLEANUP" "Limpieza de archivos"

    _cleanup_logs
    _cleanup_tmp
    _cleanup_users
    [[ "${ENABLE_SNAP_CLEANUP:-true}" == true ]] && _cleanup_snap || true
    _cleanup_apt_cache
}

# Logs
_cleanup_logs() {
    info "Limpiando logs del sistema (retención: ${LOG_DAYS} días)..."

    # En servidor suele ser mejor logrotate. Usamos vacuum-size por defecto para
    # limitar la cantidad de espacio ocupado por el journal.
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] journalctl: se aplicaría vacuum (size=${JOURNAL_VACUUM_SIZE:-200M} o tiempo=${LOG_DAYS}d)"
        return 0
    fi

    if [[ -n "${JOURNAL_VACUUM_SIZE:-}" ]]; then
        run_tolerant "journalctl vacuum" \
            journalctl --vacuum-size="${JOURNAL_VACUUM_SIZE}"
    else
        run_tolerant "journalctl vacuum" \
            journalctl --vacuum-time="${LOG_DAYS}d"
    fi

    # Reportar cuánto espacio liberó el journal
    local before after freed
    before=$(get_used_bytes)
    # A small sleep to allow journalctl to finish updating sizes (non-blocking)
    sleep 1
    after=$(get_used_bytes)
    freed=$(( before - after ))
    report_ok "journalctl vacuum: $(format_bytes ${freed:-0}) liberados"
    ok "Logs de systemd depurados"
}

# /tmp
_cleanup_tmp() {
    info "Limpiando /tmp (archivos regulares >$TMP_DAYS día(s), no abiertos)..."

    # Solo borra archivos regulares viejos y evita los que están en uso.

    local tmp_borrados=0

    if [[ "${DRY_RUN:-false}" == true ]]; then
        local tmp_borrados
        tmp_borrados=$(run_with_timeout 30 "cleanup/tmp: conteo archivos" find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" | wc -l)
        local tmp_dirs
        tmp_dirs=$(run_with_timeout 30 "cleanup/tmp: conteo directorios" find /tmp -mindepth 1 -type d -empty | wc -l)
        info "  [DRY-RUN] Se eliminarían ${tmp_borrados} archivo(s) y ${tmp_dirs} directorio(s) vacío(s) de /tmp"
        return 0
    fi

    if run_probe "fuser available" command -v fuser; then
        while IFS= read -r f; do
            if ! run_probe "fuser check on $f" fuser "$f"; then
                run_tolerant "rm -f $f" rm -f "$f"
            else
                info "  /tmp: en uso, omitido → $(basename "$f")"
            fi
        done < <(run_with_timeout 30 "cleanup/tmp: listar archivos" find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS")
    else
        warn "fuser no disponible (instalar psmisc); limpieza sin verificación de uso"
        local tmp_borrados
        tmp_borrados=$(run_with_timeout 30 "cleanup/tmp: conteo sin fuser" find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" | wc -l)
        run_tolerant "cleanup/tmp: limpiar archivos sin verificación" 30 find /tmp -mindepth 1 -type f -mtime +"$TMP_DAYS" -delete
    fi

    ok "/tmp: ${tmp_borrados} archivo(s) eliminado(s)"

    # Luego elimina directorios vacíos que hayan quedado.
    local dirs_borrados
    dirs_borrados=$(run_with_timeout 30 "cleanup/tmp: conteo dirs vacíos" find /tmp -mindepth 1 -type d -empty | wc -l)
    if (( dirs_borrados > 0 )); then
        run_tolerant "cleanup/tmp: limpiar dirs vacíos" 30 find /tmp -mindepth 1 -type d -empty -delete
        ok "/tmp: ${dirs_borrados} directorio(s) vacío(s) eliminado(s)"
    fi

    if [[ -d /var/crash ]]; then
        run_tolerant "cleanup/var-crash" bash -c 'rm -f /var/crash/*'
        ok "Reportes de crash eliminados"
    fi
}

# Apt cache
_cleanup_apt_cache() {
    info "Limpiando caché de apt..."

    if [[ "${DRY_RUN:-false}" == true ]]; then
        local apt_size
        apt_size=$(run_with_timeout 10 "measure/apt-cache" bash -c 'du -sb /var/cache/apt 2>/dev/null | cut -f1 || echo 0')
        info "  [DRY-RUN] /var/cache/apt ocupa: ${apt_size} bytes"
        return 0
    fi

    local before_total before_apt after_total freed_apt
    before_total=$(get_used_bytes)
    before_apt=$(bash -c 'du -sb /var/cache/apt 2>/dev/null | cut -f1 || echo 0')

    run_tolerant "apt-get clean" apt-get clean

    after_total=$(get_used_bytes)
    freed_apt=$(( before_total - after_total ))
    report_ok "apt-get clean: $(format_bytes ${freed_apt:-0}) liberados (cache antes: $(format_bytes ${before_apt:-0}))"
    ok "Caché de apt depurada"
}

# Caché de usuarios
_cleanup_users() {
    info "Limpiando caché y miniaturas de usuarios (retención: ${CACHE_DAYS} días)..."

    for home_dir in /home/*/; do
        [[ -d "$home_dir" ]] || continue
        local usuario; usuario=$(basename "$home_dir")

        # Miniaturas
        if [[ -d "${home_dir}.cache/thumbnails" ]]; then
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local n
                n=$(run_with_timeout 30 "cleanup/thumbnails: conteo" find "${home_dir}.cache/thumbnails" -type f -mtime +"$CACHE_DAYS" | wc -l)
                info "  [DRY-RUN] $usuario: ${n} miniatura(s) a eliminar"
            else
                run_tolerant "cleanup/thumbnails: $usuario" 30 find "${home_dir}.cache/thumbnails" -type f -mtime +"$CACHE_DAYS" -delete
                info "  Miniaturas de '$usuario' (>${CACHE_DAYS}d mtime) eliminadas"
            fi
        fi

        # Papelera
        if [[ -d "${home_dir}.local/share/Trash" ]]; then
            run_tolerant "cleanup/trash: $usuario" bash -c \
                "rm -rf '${home_dir}.local/share/Trash/files/'* \
                        '${home_dir}.local/share/Trash/info/'*"
            info "  Papelera de '$usuario' vaciada"
        fi

        # Caché general con exclusiones de configuración
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
                local n
                n=$(run_with_timeout 30 "cleanup/cache: conteo" "${find_cmd[@]}" | wc -l)
                info "  [DRY-RUN] $usuario: ${n} archivo(s) de caché a eliminar"
            else
                find_cmd+=(-delete)
                run_tolerant "cleanup/cache: $usuario" 30 "${find_cmd[@]}"
            fi
        fi
    done

    ok "Caché de usuarios procesada"
}

# Snap
_cleanup_snap() {
    if ! run_probe "snap available" command -v snap; then
        info "Snap no instalado, paso omitido"
        return 0
    fi

    info "Limpiando versiones antiguas de Snap..."

    run_with_timeout 30 "cleanup/snap: listar" snap list --all | \
        awk '/disabled/ {print $1, $3}' | \
        while read -r snap_name revision; do
            run_tolerant "cleanup/snap: $snap_name rev $revision" \
                snap remove "$snap_name" --revision="$revision"
            info "  Snap eliminado: $snap_name rev.$revision"
        done

    ok "Versiones antiguas de Snap eliminadas"
}
