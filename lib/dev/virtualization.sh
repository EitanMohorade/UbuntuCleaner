#!/bin/bash
# Limpieza de virtualizacion (libvirt y VirtualBox).

_dev_virtualization() {
    local found=false

    if command -v virsh &>/dev/null; then
        found=true
        info "libvirt detectado..."

        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] Se limpiarían logs de libvirt en /var/log/libvirt/"
        else
            run_tolerant "limpiar logs libvirt" \
                find /var/log/libvirt -type f -name "*.log" -mtime +"${LOG_DAYS}" -delete
            ok "Logs de libvirt depurados"
            report_ok "dev/virtualization/libvirt: limpieza completada"
        fi
    fi

    if command -v vboxmanage &>/dev/null; then
        found=true
        info "VirtualBox detectado..."

        while IFS=$'\t' read -r home_dir usuario; do
            local vbox_xml="${home_dir}.config/VirtualBox/VirtualBox.xml"
            local vbox_vms_dir=""

            if [[ -f "$vbox_xml" ]]; then
                vbox_vms_dir=$(grep -o 'defaultMachineFolder="[^"]*"' "$vbox_xml" \
                    | cut -d'"' -f2)
                vbox_vms_dir="${vbox_vms_dir/\~/$home_dir}"
            fi

            if [[ -z "$vbox_vms_dir" ]]; then
                vbox_vms_dir="${home_dir}VirtualBox VMs"
            fi

            if ! run_with_timeout 2 "dev/virtualization/vbox: acceso a VMs de '$usuario'" ls "$vbox_vms_dir" >/dev/null; then
                warn "VMs de '$usuario': directorio no accesible o no existe - omitiendo"
                continue
            fi

            local total_n=0
            for logs_dir in "$vbox_vms_dir"/*/Logs/; do
                if [[ ! -d "$logs_dir" ]]; then
                    continue
                fi

                if [[ "${DRY_RUN:-false}" == true ]]; then
                    local n
                    local output
                    output=$(run_with_timeout 30 "dev/virtualization/vbox: conteo logs $logs_dir" find "$logs_dir" \
                        -maxdepth 1 -xdev -type f \
                        \( -name "*.log" -o -name "*.log.*" \) \
                        -mtime +"${LOG_DAYS}")
                    n=$(printf "%s" "$output" | wc -l)
                    total_n=$(( total_n + n ))
                else
                    run_tolerant "limpiar logs VirtualBox en $logs_dir" 30 find "$logs_dir" \
                        -maxdepth 1 -xdev -type f \
                        \( -name "*.log" -o -name "*.log.*" \) \
                        -mtime +"${LOG_DAYS}" \
                        -delete
                fi
            done

            if [[ "${DRY_RUN:-false}" == true ]]; then
                info "  [DRY-RUN] $usuario - VirtualBox: ${total_n} log(s) a eliminar"
            else
                ok "Logs de VirtualBox de '$usuario' depurados"
                report_ok "dev/virtualization/virtualbox: limpieza completada para '$usuario'"
            fi
        done < <(_dev_user_homes)

        info "  [DEBUG] Loop VirtualBox completado"
    fi

    if [[ "$found" == false ]]; then
        info "Sin VMs detectadas (libvirt/VirtualBox), omitido"
        report_skip "dev/virtualization: sin VMs detectadas"
    fi

    info "  [DEBUG] Saliendo de _dev_virtualization"
}

# Alias temporal para compatibilidad con codigo antiguo.
_dev_vms() {
    _dev_virtualization
}
