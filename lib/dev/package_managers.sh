#!/bin/bash
# Limpieza de package managers.

_dev_package_managers() {
    info "Limpiando caché de package managers..."
    local found=false

    if command -v npm &>/dev/null; then
        found=true
        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] npm cache clean --force"
        else
            run_tolerant "npm cache clean" npm cache clean --force
            ok "Caché npm limpiada"
        fi
    fi

    if command -v pip3 &>/dev/null; then
        found=true
        local pip_cmd
        pip_cmd=$(command -v pip3)
        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] pip cache purge"
        else
            run_tolerant "pip cache purge" "$pip_cmd" cache purge
            ok "Caché pip limpiada"
        fi
    elif command -v pip &>/dev/null; then
        found=true
        local pip_cmd
        pip_cmd=$(command -v pip)
        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] pip cache purge"
        else
            run_tolerant "pip cache purge" "$pip_cmd" cache purge
            ok "Caché pip limpiada"
        fi
    fi

    while IFS=$'\t' read -r home_dir usuario; do
        if [[ -d "${home_dir}.gradle/caches" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local size
                size=$(du -sh "${home_dir}.gradle/caches" 2>/dev/null | cut -f1)
                info "  [DRY-RUN] $usuario Gradle cache: ${size} (archivos >$CACHE_DAYS días)"
            else
                timeout 30 find "${home_dir}.gradle/caches" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                timeout 30 find "${home_dir}.gradle/caches" -type d -empty -delete 2>/dev/null || true
                ok "Gradle cache de '$usuario' limpiada"
            fi
        fi

        if [[ -d "${home_dir}.m2/repository" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                local size
                size=$(du -sh "${home_dir}.m2/repository" 2>/dev/null | cut -f1)
                info "  [DRY-RUN] $usuario Maven repo: ${size} (solo se informa, no se limpia automáticamente)"
            else
                info "  [DEBUG] Antes find Maven"
                timeout 30 find "${home_dir}.m2/repository" \
                    -type f \
                    -path "*-SNAPSHOT*" \
                    -mtime +"$CACHE_DAYS" \
                    -delete 2>/dev/null || true
                info "  [DEBUG] Después find Maven"

                info "  [DEBUG] Antes delete dirs vacíos"
                timeout 30 find "${home_dir}.m2/repository" \
                    -type d -empty -delete 2>/dev/null || true
                info "  [DEBUG] Después delete dirs vacíos"
                ok "Maven snapshots viejos de '$usuario' eliminados"
            fi
        fi
    done < <(_dev_user_homes)

    if [[ "$found" == false ]]; then
        info "  Sin package managers detectados, omitido"
    fi
}
