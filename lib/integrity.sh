#!/bin/bash
# Verificacion e integridad de paquetes.
# Reparacion es critica; auditoria es tolerable.

run_integrity() {
    step "INTEGRITY" "Verificación e integridad de paquetes"

    _repair_packages
    _audit_dpkg
    [[ "${ENABLE_DEBSUMS:-true}" == true ]] && _check_debsums || true
}

_repair_packages() {
    info "Reparando instalaciones incompletas (dpkg + apt)..."

    # Si falla, el script debe detenerse por consistencia del sistema.
    maybe_run dpkg --configure -a
    maybe_run apt --fix-broken install -y -qq

    ok "Instalaciones reparadas"
}

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

_check_debsums() {
    info "Verificando integridad de archivos con debsums..."

    # Puede reportar cambios validos en archivos de configuracion.

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
