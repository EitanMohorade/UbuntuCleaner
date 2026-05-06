#!/bin/bash
# lib/cleanup.sh — limpieza de archivos
# Todas las operaciones son TOLERABLES: un fallo de limpieza
# no es razón para detener el mantenimiento.

run_cleanup() {
    step "CLEANUP" "Limpieza de archivos"

    _cleanup_logs
    _cleanup_tmp
    _cleanup_users
    [[ "${ENABLE_SNAP_CLEANUP:-true}" == true ]] && _cleanup_snap || true
}

# ── Logs ─────────────────────────────────────────────────────
_cleanup_logs() {
    info "Limpiando logs del sistema (retención: ${LOG_DAYS} días)..."

    # Decisión: solo journalctl para desktop/dev.
    # En servidor sería preferible: logrotate -f /etc/logrotate.conf
    # porque respeta las políticas por paquete. Para desktop,
    # journalctl es suficiente y más seguro (no toca /var/log/*).
    run_tolerant "journalctl vacuum" \
        journalctl --vacuum-time="${LOG_DAYS}d"

    ok "Logs de systemd depurados"
}

# ── /tmp ─────────────────────────────────────────────────────
_cleanup_tmp() {
    info "Limpiando /tmp (archivos regulares >$TMP_DAYS día(s), no abiertos)..."

    # Tres capas de protección:
    #   -type f  → excluye sockets (-type s), pipes (-type p),
    #              symlinks (-type l) y directorios. Evita romper
    #              apps que mantienen sockets en /tmp aunque tengan
    #              días de antigüedad (X11, DBus, MariaDB, etc.)
    #
    #   -mtime   → usamos mtime, no atime. Con relatime (default
    #              desde Linux 2.6.30), atime solo se actualiza si
    #              es menor que mtime/ctime → puede quedar congelado
    #              en archivos leídos pero no escritos.
    #
    #   fuser    → descarta archivos con descriptores abiertos.
    #              Un proceso puede mantener un fd abierto aunque el
    #              nombre no figure en /proc/*/fd de forma obvia.

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

# ── Caché de usuarios ─────────────────────────────────────────
_cleanup_users() {
    info "Limpiando caché y miniaturas de usuarios (retención: ${CACHE_DAYS} días)..."

    # -mtime (no -atime) por la razón relatime explicada arriba.
    # Navegadores excluidos: sus índices internos asumen que los archivos
    # existen. Borrar selectivamente puede corromper la caché.
    # CACHE_EXCLUDE_PATHS viene de la config.

    for home_dir in /home/*/; do
        [[ -d "$home_dir" ]] || continue
        local usuario; usuario=$(basename "$home_dir")

        # Thumbnails
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

        # Papelera
        if [[ -d "${home_dir}.local/share/Trash" ]]; then
            run_tolerant "papelera de $usuario" bash -c \
                "rm -rf '${home_dir}.local/share/Trash/files/'* \
                        '${home_dir}.local/share/Trash/info/'*"
            info "  Papelera de '$usuario' vaciada"
        fi

        # Caché general — construimos los exclusiones desde config
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

# ── Snap ──────────────────────────────────────────────────────
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
