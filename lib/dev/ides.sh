#!/bin/bash
# Limpieza de IDEs.

_dev_ides() {
    
    info "Limpiando caché de IDEs..."
    local found=false

    while IFS=$'\t' read -r home_dir usuario; do
        for vscode_dir in \
            "${home_dir}.config/Code/logs" \
            "${home_dir}.config/Code/CachedData" \
            "${home_dir}.config/Code/Cache" \
            "${home_dir}.config/Code - Insiders/logs" \
            "${home_dir}.config/Code - Insiders/CachedData"
        do
            if [[ -d "$vscode_dir" ]]; then
                found=true
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    local n
                    local output
                    output=$(run_with_timeout 30 "ides: conteo $vscode_dir" find "$vscode_dir" -type f -mtime +"$CACHE_DAYS")
                    n=$(printf "%s" "$output" | wc -l)
                    info "  [DRY-RUN] $usuario VS Code: ${n} archivo(s) en $(basename "$vscode_dir")"
                else
                    run_tolerant "ides: limpiar $vscode_dir" 30 find "$vscode_dir" -type f -mtime +"$CACHE_DAYS" -delete
                    run_tolerant "ides: limpiar dirs vacíos $vscode_dir" 30 find "$vscode_dir" -type d -empty -delete
                fi
            fi
        done

        for jb_dir in \
            "${home_dir}.cache/JetBrains" \
            "${home_dir}.local/share/JetBrains"
        do
            if [[ -d "$jb_dir" ]]; then
                found=true
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    local n
                    local output
                    output=$(run_with_timeout 30 "ides: conteo $jb_dir" find "$jb_dir" -type f -mtime +"$CACHE_DAYS")
                    n=$(printf "%s" "$output" | wc -l)
                    info "  [DRY-RUN] $usuario JetBrains: ${n} archivo(s) en $(basename "$jb_dir")"
                else
                    run_tolerant "ides: limpiar $jb_dir" 30 find "$jb_dir" -type f -mtime +"$CACHE_DAYS" -delete
                    run_tolerant "ides: limpiar dirs vacíos $jb_dir" 30 find "$jb_dir" -type d -empty -delete
                fi
            fi
        done
    done < <(_dev_user_homes)

    if [[ "$found" == false ]]; then
        info "  Sin IDEs detectados (VS Code/JetBrains), omitido"
        report_skip "dev/ides: sin IDEs detectados"
    else
        ok "Caché de IDEs limpiada"
        report_ok "dev/ides: limpieza completada"
    fi
}
