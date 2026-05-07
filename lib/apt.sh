#!/bin/bash
# Operaciones APT criticas: si fallan, se detiene el flujo.

run_apt() {
    step "APT" "Actualización del sistema"

    # Fuerza modo no interactivo para evitar prompts de debconf.
    local APT_ENV="env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true"

    info "Actualizando repositorios..."
    maybe_run $APT_ENV apt update -qq
    ok "Repositorios actualizados"

    info "Actualizando paquetes instalados..."
    maybe_run $APT_ENV apt upgrade -y -qq
    ok "Sistema actualizado"

    info "Eliminando paquetes huérfanos..."
    maybe_run $APT_ENV apt autoremove --purge -y -qq
    ok "Paquetes huérfanos eliminados"

    info "Limpiando caché de APT..."
    maybe_run $APT_ENV apt clean
    maybe_run $APT_ENV apt autoclean -qq
    ok "Caché de APT limpiada"
}