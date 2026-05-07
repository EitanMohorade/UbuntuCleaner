#!/bin/bash

# Entrypoint principal.
# Uso recomendado: sudo mantenimiento-ubuntu [opciones]

set -euo pipefail

# Resuelve el path real para soportar ejecucion via symlink.
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Carga librerias compartidas y modulos.
source "${ROOT_DIR}/lib/core.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/apt.sh"
source "${ROOT_DIR}/lib/cleanup.sh"
source "${ROOT_DIR}/lib/integrity.sh"
source "${ROOT_DIR}/lib/disk.sh"

# Orden de ejecucion de modulos.
MODULES_AVAILABLE=(apt cleanup integrity disk)

# Argumentos CLI.
DRY_RUN=false
MODULES_ONLY=()
MODULES_SKIP=()

show_help() {
    cat <<EOF
Uso: sudo bash bin/mantenimiento.sh [opciones]

Opciones:
  --dry-run            Simula la ejecución sin modificar nada
  --only=m1,m2,...     Ejecuta solo los módulos indicados
  --skip=m1,m2,...     Omite los módulos indicados
  --help               Muestra esta ayuda

Módulos disponibles: ${MODULES_AVAILABLE[*]}

Ejemplos:
  sudo bash bin/mantenimiento.sh --dry-run
  sudo bash bin/mantenimiento.sh --only=apt,cleanup
  sudo bash bin/mantenimiento.sh --skip=disk
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --only=*)
            IFS=',' read -ra MODULES_ONLY <<< "${arg#--only=}"
            ;;
        --skip=*)
            IFS=',' read -ra MODULES_SKIP <<< "${arg#--skip=}"
            ;;
        --help|-h)
            show_help; exit 0
            ;;
        *)
            echo "Argumento desconocido: $arg" >&2
            show_help; exit 1
            ;;
    esac
done

# Valida nombres de modulos pasados por el usuario.
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

# Determina si un modulo debe ejecutarse.
_should_run() {
    local module="$1"

    # Si hay --only, ejecutar solo los listados.
    if [[ ${#MODULES_ONLY[@]} -gt 0 ]]; then
        for m in "${MODULES_ONLY[@]}"; do
            [[ "$m" == "$module" ]] && return 0
        done
        return 1
    fi

    # Si hay --skip, omitir los listados.
    for m in "${MODULES_SKIP[@]}"; do
        [[ "$m" == "$module" ]] && return 1
    done

    return 0
}

# Requiere privilegios de root.
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m  ✘ Este script debe ejecutarse como root: sudo bash bin/mantenimiento.sh\033[0m"
    exit 1
fi

# Carga y valida configuracion.
load_config "$ROOT_DIR"
validate_config

# Configuracion de logs.
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date '+%Y-%m').log"

# Limpia logs antiguos del script.
find "$LOG_DIR" -name "*.log" -mtime +"${SCRIPT_LOG_KEEP_DAYS}" -delete 2>/dev/null || true

# Captura espacio inicial.
ESPACIO_INICIAL=$(get_used_mb)

_log "${BOLD}"
_log "╔══════════════════════════════════════════╗"
_log "║     MANTENIMIENTO DEL SISTEMA UBUNTU     ║"
[[ "$DRY_RUN" == true ]] && _log "║           *** MODO DRY-RUN ***           ║"
_log "╚══════════════════════════════════════════╝"
_log "${RESET}"
_log "  Espacio usado al inicio : ${YELLOW}${ESPACIO_INICIAL} MB${RESET}  (/, /home, /var sumados)"
_log "  Fecha                   : $(date '+%d/%m/%Y %H:%M:%S')"
_log "  Log                     : ${LOG_FILE}\n"

# Ejecuta modulos.
MODULES_RAN=()

for module in "${MODULES_AVAILABLE[@]}"; do
    if _should_run "$module"; then
        "run_${module}"
        MODULES_RAN+=("$module")
    else
        info "Módulo '${module}' omitido"
    fi
done

# Resumen final.
ESPACIO_FINAL=$(get_used_mb)
LIBERADO=$(( ESPACIO_INICIAL - ESPACIO_FINAL ))

_log "\n${BOLD}"
_log "╔══════════════════════════════════════════╗"
_log "║              RESUMEN FINAL               ║"
_log "╚══════════════════════════════════════════╝"
_log "${RESET}"
_log "  Espacio usado antes  : ${YELLOW}${ESPACIO_INICIAL} MB${RESET}"

if [[ "$DRY_RUN" == true ]]; then
    _log "  Espacio usado ahora  : ${CYAN}(sin cambios — modo dry-run)${RESET}"
else
    _log "  Espacio usado ahora  : ${GREEN}${ESPACIO_FINAL} MB${RESET}"
    if (( LIBERADO > 0 )); then
        _log "  Espacio liberado     : ${GREEN}${BOLD}${LIBERADO} MB${RESET}"
    else
        _log "  Espacio liberado     : ${CYAN}0 MB (el sistema ya estaba limpio)${RESET}"
    fi
fi

_log "  Módulos ejecutados   : ${MODULES_RAN[*]:-ninguno}"

if [[ ${#ERRORES_NO_CRITICOS[@]} -gt 0 ]]; then
    _log "\n  ${YELLOW}${BOLD}Advertencias no críticas:${RESET}"
    for e in "${ERRORES_NO_CRITICOS[@]}"; do
        _log "    ${YELLOW}•${RESET} $e"
    done
fi

_log "\n  ${BOLD}Recomendación:${RESET} reiniciá el equipo para aplicar"
_log "  actualizaciones y el chequeo de disco.\n"

# Guarda metadatos de la ejecucion.
STATE_FILE="${ROOT_DIR}/state/last_run.json"
save_state "$STATE_FILE" "$ESPACIO_INICIAL" "$ESPACIO_FINAL" "${MODULES_RAN[*]:-}"