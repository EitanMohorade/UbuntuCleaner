#!/bin/bash
# lib/integrity.sh — verificación e integridad de paquetes
# Equivalente a sfc /scannow de Windows.
#
# Política mixta:
#   dpkg --configure -a + apt --fix-broken → CRÍTICO
#   dpkg --audit + debsums                 → TOLERABLE

run_integrity() {
    step "INTEGRITY" "Verificación e integridad de paquetes"

    _repair_packages
    _audit_dpkg
    [[ "${ENABLE_DEBSUMS:-true}" == true ]] && _check_debsums || true
}

# ── Reparación de paquetes  (CRÍTICO) ─────────────────────────
_repair_packages() {
    info "Reparando instalaciones incompletas (dpkg + apt)..."

    # Si esto falla, el sistema puede estar en estado inconsistente.
    # Correcto que set -e lo detenga: continuar con un dpkg roto
    # podría empeorar la situación.
    maybe_run dpkg --configure -a
    maybe_run apt --fix-broken install -y -qq

    ok "Instalaciones reparadas"
}

# ── Auditoría dpkg  (TOLERABLE) ───────────────────────────────
_audit_dpkg() {
    info "Auditando base de datos de dpkg..."

    local audit; audit=$(dpkg --audit 2>&1 || true)
    if [[ -z "$audit" ]]; then
        ok "Base de datos de dpkg sin problemas"
    else
        warn "dpkg --audit encontró inconvenientes:"
        echo "$audit"
        ERRORES_NO_CRITICOS+=("dpkg audit con hallazgos")
    fi
}

# ── debsums  (TOLERABLE) ──────────────────────────────────────
_check_debsums() {
    info "Verificando integridad de archivos con debsums..."

    # debsums puede dar falsos positivos en archivos de configuración
    # modificados intencionalmente por el usuario o por otros paquetes.
    # Por eso es TOLERABLE, no crítico.

    if ! command -v debsums &>/dev/null; then
        run_tolerant "instalar debsums" apt install -y -qq debsums
    fi

    if ! command -v debsums &>/dev/null; then
        warn "debsums no pudo instalarse, verificación omitida"
        ERRORES_NO_CRITICOS+=("debsums no disponible")
        return 0
    fi

    local debsums_out; debsums_out=$(debsums -s 2>&1 || true)
    if [[ -z "$debsums_out" ]]; then
        ok "Todos los archivos de paquetes están íntegros"
    else
        warn "debsums detectó archivos modificados o faltantes:"
        echo "$debsums_out"
        warn "Para reinstalar un paquete: sudo apt install --reinstall <paquete>"
        ERRORES_NO_CRITICOS+=("debsums con hallazgos")
    fi
}
