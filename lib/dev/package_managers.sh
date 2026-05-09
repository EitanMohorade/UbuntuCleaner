#!/bin/bash
# Limpieza de package managers.

_dev_package_managers() {
    info "Limpiando caché de package managers..."
    local found=false

    if run_probe "npm available" command -v npm; then
        found=true
        previewable_run "npm cache clean" "npm cache clean --force" npm cache clean --force
        [[ "${DRY_RUN:-false}" != true ]] && ok "Caché npm limpiada"
    fi

    if run_probe "pip3 available" command -v pip3; then
        found=true
        local pip_cmd
        pip_cmd=$(run_tolerant "get pip3 path" command -v pip3)
        previewable_run "pip cache purge" "pip3 cache purge" "$pip_cmd" cache purge
        [[ "${DRY_RUN:-false}" != true ]] && ok "Caché pip limpiada"
    elif run_probe "pip available" command -v pip; then
        found=true
        local pip_cmd
        pip_cmd=$(run_tolerant "get pip path" command -v pip)
        previewable_run "pip cache purge" "pip cache purge" "$pip_cmd" cache purge
        [[ "${DRY_RUN:-false}" != true ]] && ok "Caché pip limpiada"
    fi

    while IFS=$'\t' read -r home_dir usuario; do
        if [[ -d "${home_dir}.gradle/caches" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local size
                size=$(run_with_timeout 30 "dev/package-managers: du gradle" du -sh "${home_dir}.gradle/caches" | cut -f1)
                info "  [DRY-RUN] $usuario Gradle cache: ${size}"
            else
                run_tolerant "gradle cache cleanup for $usuario" 30 find "${home_dir}.gradle/caches" -type f -mtime +"$CACHE_DAYS" -delete
                run_tolerant "gradle empty dirs cleanup for $usuario" 30 find "${home_dir}.gradle/caches" -type d -empty -delete
                ok "Gradle cache de '$usuario' limpiada"
            fi
        fi

        if [[ -d "${home_dir}.m2/repository" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local size
                size=$(run_with_timeout 30 "dev/package-managers: du maven" du -sh "${home_dir}.m2/repository" | cut -f1)
                info "  [DRY-RUN] $usuario Maven repo: ${size}"
            else
                run_tolerant "maven snapshots cleanup for $usuario" 30 find "${home_dir}.m2/repository" \
                    -type f \
                    -path "*-SNAPSHOT*" \
                    -mtime +"$CACHE_DAYS" \
                    -delete
                run_tolerant "maven empty dirs cleanup for $usuario" 30 find "${home_dir}.m2/repository" \
                    -type d -empty -delete
                ok "Maven snapshots viejos de '$usuario' eliminados"
            fi
        fi
    done < <(_dev_user_homes)

    if [[ "$found" == false ]]; then
        info "  Sin package managers detectados, omitido"
        report_skip "dev/package-managers: sin herramientas detectadas"
    else
        report_ok "dev/package-managers: limpieza completada"
    fi
}
