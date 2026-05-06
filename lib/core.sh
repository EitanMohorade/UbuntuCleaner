#!/bin/bash
# lib/core.sh — utilidades base
# Sourced primero; no ejecuta nada al cargar.

# ── Colores ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────
# LOG_FILE se define antes de sourcing (en el entrypoint).
# Si no está seteado, los mensajes van solo a stdout.

_log() {
    local line="$*"
    echo -e "$line"
    if [[ -n "${LOG_FILE:-}" ]]; then
        # Strip escape codes antes de escribir al archivo
        echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

ok()   { _log "${GREEN}  ✔ $*${RESET}"; }
info() { _log "${CYAN}  → $*${RESET}"; }
warn() { _log "${YELLOW}  ⚠ $*${RESET}"; }
err()  { _log "${RED}  ✘ $*${RESET}"; }
step() { _log "\n${BOLD}[$1] $2${RESET}"; }

# ── Errores diferenciados ─────────────────────────────────────
#
# Política de errores:
#   CRÍTICO  → correr directamente bajo set -euo pipefail.
#              Si falla, el script se detiene. Correcto: dejar el
#              sistema en estado inconsistente sería peor.
#
#   TOLERABLE → usar run_tolerant(). El fallo se captura, se
#               registra en ERRORES_NO_CRITICOS[] y se continúa.
#               El || true está ENCAPSULADO aquí, con intención
#               explícita. No aparece disperso en el código.
#
ERRORES_NO_CRITICOS=()

run_tolerant() {
    # Uso: run_tolerant "descripción legible" comando [args...]
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
        return 0  # <── no propagamos; set -e no se activa
    fi
}

# ── Dry-run wrapper ───────────────────────────────────────────
maybe_run() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# ── Medición de espacio real en disco ─────────────────────────
#
# Se excluyen filesystems virtuales para que el delta refleje
# solo espacio real en disco, sin importar cómo estén particionadas
# /, /home o /var.
#   tmpfs    → RAM
#   devtmpfs → pseudo-FS de dispositivos
#   squashfs → cada snap monta uno
#   overlay  → Docker/contenedores
#
get_used_mb() {
    df -BM -x tmpfs -x devtmpfs -x squashfs -x overlay --output=used 2>/dev/null \
        | tail -n +2 \
        | tr -d ' M' \
        | awk 'NF && /^[0-9]+$/ {s += $1} END {print (s ? s : 0)}'
}

# ── Guardar estado JSON ───────────────────────────────────────
save_state() {
    local state_file="$1"
    local space_before="$2"
    local space_after="$3"
    local modules_run="$4"    # string separada por espacios
    local dry_run="${DRY_RUN:-false}"

    local freed=$(( space_before - space_after ))
    local warnings_json=""

    for e in "${ERRORES_NO_CRITICOS[@]:-}"; do
        [[ -z "$e" ]] && continue
        warnings_json+="\"${e}\","
    done
    warnings_json="[${warnings_json%,}]"

    # Convertir módulos a array JSON
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
