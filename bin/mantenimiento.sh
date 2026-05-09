#!/bin/bash

# Entry point del script.
# Uso:
#   sudo bash bin/mantenimiento.sh
#   sudo bash bin/mantenimiento.sh --dry-run
#   sudo bash bin/mantenimiento.sh --only=apt,cleanup,dev
#   sudo bash bin/mantenimiento.sh --skip=disk
#   sudo bash bin/mantenimiento.sh --help

set -euo pipefail
trap 'echo "[FATAL] línea $LINENO: comando falló: $BASH_COMMAND"' ERR

# Rutas del script.
# readlink -f resuelve el symlink antes de calcular el directorio.
# Así ROOT_DIR se calcula bien aunque se ejecute desde un enlace.
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Carga de módulos.
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/apt.sh"
source "${ROOT_DIR}/lib/cleanup.sh"
source "${ROOT_DIR}/lib/integrity.sh"
source "${ROOT_DIR}/lib/disk.sh"
source "${ROOT_DIR}/lib/dev.sh"

# Módulos disponibles.
MODULES_AVAILABLE=(apt cleanup integrity disk dev)

# Parseo de argumentos.
DRY_RUN=false
MODULES_ONLY=()
MODULES_SKIP=()

show_help() {
    cat <<EOF
Uso: sudo bash bin/mantenimiento.sh [opciones]

Opciones:
  --dry-run            Simula sin modificar nada
  --only=m1,m2,...     Ejecuta solo los módulos indicados
  --skip=m1,m2,...     Omite los módulos indicados
  --help               Muestra esta ayuda

Módulos disponibles: ${MODULES_AVAILABLE[*]}
  apt        → update, upgrade, autoremove, clean (apt-get)
  cleanup    → logs, /tmp, caché de usuarios, snap
  integrity  → dpkg audit + debsums
  disk       → fsck / btrfs scrub / xfs_repair
  dev        → Docker, VMs, IDEs, npm/pip/gradle/maven, DBs

Ejemplos:
  sudo bash bin/mantenimiento.sh --dry-run
  sudo bash bin/mantenimiento.sh --only=apt,cleanup
  sudo bash bin/mantenimiento.sh --skip=disk,dev
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --only=*)    IFS=',' read -ra MODULES_ONLY <<< "${arg#--only=}" ;;
        --skip=*)    IFS=',' read -ra MODULES_SKIP <<< "${arg#--skip=}" ;;
        --help|-h)   show_help; exit 0 ;;
        *)           echo "Argumento desconocido: $arg" >&2; show_help; exit 1 ;;
    esac
done

# Validación de módulos.
_validate_module_names() {
    local -a input=("$@")
    for m in "${input[@]}"; do
        local valid=false
        for a in "${MODULES_AVAILABLE[@]}"; do
            [[ "$m" == "$a" ]] && valid=true && break
        done
        if [[ "$valid" == false ]]; then
            err "Módulo desconocido: '$m'. Disponibles: ${MODULES_AVAILABLE[*]}"
            exit 1
        fi
    done
}
[[ ${#MODULES_ONLY[@]} -gt 0 ]] && _validate_module_names "${MODULES_ONLY[@]}"
[[ ${#MODULES_SKIP[@]} -gt 0 ]] && _validate_module_names "${MODULES_SKIP[@]}"

_should_run() {
    local module="$1"
    if [[ ${#MODULES_ONLY[@]} -gt 0 ]]; then
        for m in "${MODULES_ONLY[@]}"; do [[ "$m" == "$module" ]] && return 0; done
        return 1
    fi
    for m in "${MODULES_SKIP[@]}"; do [[ "$m" == "$module" ]] && return 1; done
    return 0
}

# Verifica privilegios de root.
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m  ✘ Ejecutar como root: sudo bash bin/mantenimiento.sh\033[0m"
    exit 1
fi

# Carga y valida configuración.
load_config "$ROOT_DIR"
validate_config

# Configura el log.
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date '+%Y-%m').log"
find "$LOG_DIR" -name "*.log" -mtime +"${SCRIPT_LOG_KEEP_DAYS}" -delete 2>/dev/null || true

# Snapshot inicial de espacio.
# Se mide antes de cualquier operación.
BYTES_ANTES=$(get_used_bytes)

_log "${BOLD}"
_log "╔══════════════════════════════════════════╗"
_log "║     MANTENIMIENTO DEL SISTEMA UBUNTU     ║"
[[ "$DRY_RUN" == true ]] && \
_log "║           *** MODO DRY-RUN ***           ║"
_log "╚══════════════════════════════════════════╝"
_log "${RESET}"
_log "  Espacio usado al inicio : ${YELLOW}$(format_bytes "$BYTES_ANTES")${RESET}  (/, /home, /var sumados)"
_log "  Fecha                   : $(date '+%d/%m/%Y %H:%M:%S')"
_log "  Log                     : ${LOG_FILE}\n"

# Ejecución de módulos.
MODULES_RAN=()

for module in "${MODULES_AVAILABLE[@]}"; do
    if _should_run "$module"; then
        "run_${module}"
        MODULES_RAN+=("$module")
    else
        info "Módulo '${module}' omitido"
    fi
done

# Snapshot final.
BYTES_DESPUES=$(get_used_bytes)
BYTES_LIBERADOS=$(( BYTES_ANTES - BYTES_DESPUES ))

_log "\n${BOLD}"
_log "╔══════════════════════════════════════════╗"
_log "║              RESUMEN FINAL               ║"
_log "╚══════════════════════════════════════════╝"
_log "${RESET}"
_log "  Espacio usado antes  : ${YELLOW}$(format_bytes "$BYTES_ANTES")${RESET}"

if [[ "$DRY_RUN" == true ]]; then
    _log "  Espacio usado ahora  : ${CYAN}(sin cambios — modo dry-run)${RESET}"
else
    _log "  Espacio usado ahora  : ${GREEN}$(format_bytes "$BYTES_DESPUES")${RESET}"
    if (( BYTES_LIBERADOS > 0 )); then
        _log "  Espacio liberado     : ${GREEN}${BOLD}$(format_bytes "$BYTES_LIBERADOS")${RESET} 🎉"
    elif (( BYTES_LIBERADOS < 0 )); then
        # Puede pasar si una actualización instaló más paquetes de los que quitó.
        _log "  Espacio usado        : ${YELLOW}+$(format_bytes $(( -BYTES_LIBERADOS ))) (actualizaciones instaladas)${RESET}"
    else
        _log "  Espacio liberado     : ${CYAN}0 B (el sistema ya estaba limpio)${RESET}"
    fi

    # Detalle por filesystem.
    _log "\n  ${BOLD}Detalle por partición:${RESET}"
    while IFS=$'\t' read -r mountpoint used_bytes; do
        printf "    %-20s %s\n" "$mountpoint" "$(format_bytes "$used_bytes")"
    done < <(get_space_breakdown)
fi

_log "  Módulos ejecutados   : ${MODULES_RAN[*]:-ninguno}"

if [[ ${#ERRORES_NO_CRITICOS[@]} -gt 0 ]]; then
    _log "\n  ${YELLOW}${BOLD}Advertencias no críticas:${RESET}"
    for e in "${ERRORES_NO_CRITICOS[@]}"; do
        _log "    ${YELLOW}•${RESET} $e"
    done
fi

# Verifica si hace falta reiniciar.
if [[ -f /var/run/reboot-required ]]; then
    _log ""
    warn "Reinicio requerido por el sistema"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        pkgs=$(tr '\n' ' ' < /var/run/reboot-required.pkgs)
        warn "  Paquetes que lo requieren: ${pkgs}"
    fi
else
    _log "  ${CYAN}→ No se requiere reinicio${RESET}"
fi

_log ""

# Guarda el estado JSON.
STATE_FILE="${ROOT_DIR}/state/last_run.json"
save_state "$STATE_FILE" "$BYTES_ANTES" "$BYTES_DESPUES" "${MODULES_RAN[*]:-}"
