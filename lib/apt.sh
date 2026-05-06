#!/bin/bash
# lib/apt.sh — operaciones de APT
# Todas CRÍTICAS: si fallan, set -e detiene el script.
# Un sistema con apt roto no debería continuar con limpieza.

run_apt() {
    step "APT" "Actualización del sistema"

    # DEBIAN_FRONTEND=noninteractive suprime todos los prompts de debconf
    # durante la ejecución de apt. Sin esto, paquetes como `code` (VS Code)
    # o `grub` pueden lanzar diálogos interactivos que bloquean el script
    # aunque se use -y.
    #
    # DEBCONF_NONINTERACTIVE_SEEN=true le indica a debconf que ya "vio"
    # los prompts y no necesita mostrarlos. Ambas variables trabajan juntas:
    # DEBIAN_FRONTEND elige el modo, DEBCONF_NONINTERACTIVE_SEEN evita
    # que algunos paquetes fuercen el frontend interactivo igual.
    #
    # Se pasan con `env` para no contaminar el entorno del resto del script.
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