#!/bin/bash
# Utilidades base.
# Se carga primero y no ejecuta nada al cargarse.

# Colores.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# Logging.
_log() {
    local line="$*"
    echo -e "$line"
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

ok()   { _log "${GREEN}  ✔ $*${RESET}"; }
info() { _log "${CYAN}  → $*${RESET}"; }
warn() { _log "${YELLOW}  ⚠ $*${RESET}"; }
err()  { _log "${RED}  ✘ $*${RESET}"; }
step() { _log "\n${BOLD}[$1] $2${RESET}"; }

# Errores diferenciados.
ERRORES_NO_CRITICOS=()

run_tolerant() {
    local desc="$1"; shift
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
        return 0
    fi
    local tmp_err; tmp_err=$(mktemp)
    if "$@" 2>"$tmp_err"; then
        rm -f "$tmp_err"; return 0
    else
        local msg; msg=$(head -1 "$tmp_err" 2>/dev/null || true)
        rm -f "$tmp_err"
        warn "No crítico — ${desc}: ${msg:-sin detalle}"
        ERRORES_NO_CRITICOS+=("$desc")
        return 0
    fi
}

maybe_run() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# Medición de espacio.
# Suma el uso de disco de los filesystems reales.
# Excluye tmpfs, devtmpfs, squashfs y overlay.
get_used_bytes() {
    df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay --output=used 2>/dev/null \
        | tail -n +2 \
        | tr -d ' ' \
        | awk 'NF && /^[0-9]+$/ {s += $1} END {print (s ? s : 0)}'
}

# Retorna una tabla "mountpoint<TAB>used_bytes" para los FS reales.
# Usado para el breakdown por partición en el resumen.
get_space_breakdown() {
    df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay \
        --output=target,used 2>/dev/null \
        | tail -n +2
}

# Formatea bytes a la unidad más legible (B / KB / MB / GB)
format_bytes() {
    local bytes="$1"
    if   (( bytes < 1024 ));              then echo "${bytes} B"
    elif (( bytes < 1024 * 1024 ));       then awk "BEGIN{printf \"%.1f KB\", $bytes/1024}"
    elif (( bytes < 1024 * 1024 * 1024)); then awk "BEGIN{printf \"%.1f MB\", $bytes/1024/1024}"
    else                                       awk "BEGIN{printf \"%.2f GB\", $bytes/1024/1024/1024}"
    fi
}

# Estado JSON.
save_state() {
    local state_file="$1"
    local space_before="$2"   # bytes
    local space_after="$3"    # bytes
    local modules_run="$4"
    local dry_run="${DRY_RUN:-false}"
    local freed=$(( space_before - space_after ))

    local warnings_json=""
    for e in "${ERRORES_NO_CRITICOS[@]:-}"; do
        [[ -z "$e" ]] && continue
        warnings_json+="\"${e}\","
    done
    warnings_json="[${warnings_json%,}]"

    local mods_json=""
    for m in $modules_run; do
        mods_json+="\"${m}\","
    done
    mods_json="[${mods_json%,}]"

    mkdir -p "$(dirname "$state_file")"
    cat > "$state_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "dry_run": ${dry_run},
  "space_before_bytes": ${space_before},
  "space_after_bytes": ${space_after},
  "space_freed_bytes": ${freed},
  "space_freed_human": "$(format_bytes $(( freed > 0 ? freed : 0 )))",
  "modules_run": ${mods_json},
  "warnings": ${warnings_json}
}
EOF
}
