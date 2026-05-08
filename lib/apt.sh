#!/bin/bash
# Operaciones de APT para scripts.
# Usamos apt-get porque su interfaz es estable para automatización.

run_apt() {
    step "APT" "Actualización del sistema"

    # Evita diálogos interactivos de debconf durante la ejecución.
    local APT_ENV="env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true"

    info "Actualizando repositorios..."
    maybe_run $APT_ENV apt-get update -qq
    ok "Repositorios actualizados"

    info "Actualizando paquetes instalados..."
    maybe_run $APT_ENV apt-get upgrade -y -qq
    ok "Sistema actualizado"

    info "Eliminando paquetes huérfanos..."
    maybe_run $APT_ENV apt-get autoremove --purge -y -qq
    ok "Paquetes huérfanos eliminados"

    info "Limpiando caché de APT..."
    maybe_run $APT_ENV apt-get clean
    maybe_run $APT_ENV apt-get autoclean -qq
    ok "Caché de APT limpiada"

    _repair_if_needed
}

# Reparación solo cuando dpkg reporta paquetes rotos.
_repair_if_needed() {
    local audit_output
    audit_output=$(dpkg --audit 2>&1 || true)

    if [[ -z "$audit_output" ]]; then
        ok "Paquetes íntegros — reparación no necesaria"
        return 0
    fi

    warn "dpkg --audit detectó inconvenientes — iniciando reparación:"
    echo "$audit_output"

    info "Reparando paquetes incompletos..."
    maybe_run dpkg --configure -a
    maybe_run env DEBIAN_FRONTEND=noninteractive apt-get --fix-broken install -y -qq
    ok "Reparación completada"
}
