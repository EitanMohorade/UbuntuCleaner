#!/bin/bash
# Chequeo de filesystem tolerable: si falla, se registra y continua.

run_disk() {
    [[ "${ENABLE_FSCK:-true}" == true ]] || { info "ENABLE_FSCK=false, módulo omitido"; return 0; }

    step "DISK" "Chequeo del sistema de archivos"

    local root_dev; root_dev=$(findmnt -n -o SOURCE /)
    local root_fs;  root_fs=$(findmnt -n -o FSTYPE /)

    case "$root_fs" in
        ext2|ext3|ext4) _fsck_ext "$root_dev" "$root_fs" ;;
        btrfs)           _fsck_btrfs ;;
        xfs)             _fsck_xfs "$root_dev" ;;
        *)
            warn "Filesystem '$root_fs' no reconocido; chequeo manual recomendado"
            ERRORES_NO_CRITICOS+=("fsck: filesystem $root_fs no soportado")
            ;;
    esac
}

_fsck_ext() {
    local dev="$1" fs="$2"

    # Programa un fsck puntual avanzando el contador de montajes,
    # sin alterar la politica persistente del filesystem.

    local max_mnt; max_mnt=$(tune2fs -l "$dev" 2>/dev/null \
        | awk '/^Maximum mount count/{print $4}')

    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] Se avanzaría el contador de montajes en $dev ($fs)"
        return 0
    fi

    if [[ -z "$max_mnt" ]]; then
        warn "No se pudo leer el max-mount-count de $dev"
        ERRORES_NO_CRITICOS+=("fsck: no se pudo leer tune2fs en $dev")
        return 0
    fi

    if (( max_mnt > 0 )); then
        run_tolerant "avanzar mount count en $dev" \
            tune2fs -C $(( max_mnt - 1 )) "$dev"
        ok "fsck puntual programado en próximo reinicio ($dev, $fs)"
        info "  Política sin cambios — max-mount-counts=$max_mnt"
    else
        # max_mnt == -1: fsck por contador deshabilitado.
        warn "fsck por contador deshabilitado en $dev (max=-1)"
        warn "Para un chequeo manual: sudo fsck $dev"
        ERRORES_NO_CRITICOS+=("fsck deshabilitado en $dev")
    fi
}

_fsck_btrfs() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] Se iniciaría btrfs scrub en /"
        return 0
    fi
    run_tolerant "btrfs scrub start" btrfs scrub start /
    ok "Btrfs scrub iniciado en background (puede tardar minutos)"
}

_fsck_xfs() {
    local dev="$1"
    # xfs_repair -n solo verifica; no modifica datos.
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] Se ejecutaría xfs_repair -n $dev"
        return 0
    fi
    run_tolerant "xfs_repair -n" xfs_repair -n "$dev"
    ok "xfs_repair (modo lectura) ejecutado"
}
