#!/bin/bash
# Utilidades base compartidas por todos los modulos.

# Colores para salida en consola.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# Si LOG_FILE existe, tambien escribe sin codigos ANSI.

_log() {
    local line="$*"
    echo -e "$line"
    if [[ -n "${LOG_FILE:-}" ]]; then
        # Limpia codigos ANSI para guardar texto plano.
        echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

ok()   { _log "${GREEN}  ✔ $*${RESET}"; }
info() { _log "${CYAN}  → $*${RESET}"; }
warn() { _log "${YELLOW}  ⚠ $*${RESET}"; }
err()  { _log "${RED}  ✘ $*${RESET}"; }
step() { _log "\n${BOLD}[$1] $2${RESET}"; }

# Errores tolerables: registra advertencia y continua.
ERRORES_NO_CRITICOS=()

run_tolerant() {
    # Uso: run_tolerant "descripcion" comando [args...]
    local desc="$1"; shift

    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
        return 0
    fi

    local tmp_err; tmp_err=$(mktemp)
    if "$@" 2>"$tmp_err"; then
        rm -f "$tmp_err"
        return 0
    else
        local msg; msg=$(head -1 "$tmp_err" 2>/dev/null || true)
        rm -f "$tmp_err"
        warn "No crítico — ${desc}: ${msg:-sin detalle}"
        ERRORES_NO_CRITICOS+=("$desc")
        return 0
    fi
}

    # Ejecuta o simula segun DRY_RUN.
maybe_run() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# Suma espacio usado excluyendo filesystems virtuales.
get_used_mb() {
    df -BM -x tmpfs -x devtmpfs -x squashfs -x overlay --output=used 2>/dev/null \
        | tail -n +2 \
        | tr -d ' M' \
        | awk 'NF && /^[0-9]+$/ {s += $1} END {print (s ? s : 0)}'
}

# Guarda estado de la ultima ejecucion en JSON.
save_state() {
    local state_file="$1"
    local space_before="$2"
    local space_after="$3"
    local modules_run="$4"
    local dry_run="${DRY_RUN:-false}"

    local freed=$(( space_before - space_after ))
    local warnings_json=""

    for e in "${ERRORES_NO_CRITICOS[@]:-}"; do
        [[ -z "$e" ]] && continue
        warnings_json+="\"${e}\","
    done
    warnings_json="[${warnings_json%,}]"

    # Convierte modulos a array JSON.
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
  "space_before_mb": ${space_before},
  "space_after_mb": ${space_after},
  "space_freed_mb": ${freed},
  "modules_run": ${mods_json},
  "warnings": ${warnings_json}
}
EOF
}
