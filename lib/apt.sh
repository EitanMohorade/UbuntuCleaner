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

    info "Comprobando actualizaciones disponibles..."
    if [[ "${DRY_RUN:-false}" == true ]]; then
        # En dry-run mostramos qué paquetes serían actualizados
        local upg_list
        upg_list=$(apt list --upgradable 2>/dev/null | sed -n '2,$p') || true
        local upg_count
        upg_count=$(printf "%s" "$upg_list" | sed -n '$=' 2>/dev/null || echo 0)
        info "  [DRY-RUN] Paquetes actualizables: ${upg_count}"
        [[ -n "$upg_list" ]] && info "$upg_list"
        ok "Comprobación de actualizaciones (modo dry-run)"
    else
        local upg_before upg_after installed_count
        upg_before=$(apt list --upgradable 2>/dev/null | sed -n '2,$p' | wc -l || echo 0)

        info "Actualizando paquetes instalados... (${upg_before} pendientes detectadas)"
        # Medimos espacio antes para poder atribuir cambios a la actualización
        local space_before; space_before=$(get_used_bytes)

        run_tolerant "apt-get upgrade" $APT_ENV apt-get upgrade -y -qq

        # Recontar paquetes pendientes
        upg_after=$(apt list --upgradable 2>/dev/null | sed -n '2,$p' | wc -l || echo 0)
        installed_count=$(( upg_before - upg_after ))

        local space_after; space_after=$(get_used_bytes)
        local delta=$(( space_before - space_after ))

        if (( installed_count > 0 )); then
            report_ok "apt: ${installed_count} paquete(s) actualizados"
            ok "Sistema actualizado: ${installed_count} paquete(s) instalados"
        else
            report_skip "apt: no había actualizaciones disponibles"
            ok "Sistema: no había actualizaciones"
        fi

        # Si el espacio cambió, reportarlo (actualizaciones pueden aumentar uso)
        if (( delta > 0 )); then
            report_ok "apt: $(format_bytes ${delta}) liberados tras actualización"
        elif (( delta < 0 )); then
            report_warn "apt: uso aumentado $(format_bytes $(( -delta ))) tras actualización"
        fi
    fi

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
    audit_output=$(run_tolerant "dpkg audit" dpkg --audit)

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
