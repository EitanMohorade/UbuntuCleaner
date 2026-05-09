#!/bin/bash
# Limpieza de IDEs.

_dev_ides() {
    info "  [DEBUG] Entrando a _dev_ides"
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
                    n=$(timeout 30 find "$vscode_dir" -type f -mtime +"$CACHE_DAYS" 2>/dev/null | wc -l)
                    info "  [DRY-RUN] $usuario VS Code: ${n} archivo(s) en $(basename "$vscode_dir")"
                else
                    timeout 30 find "$vscode_dir" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                    timeout 30 find "$vscode_dir" -type d -empty -delete 2>/dev/null || true
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
                    n=$(timeout 30 find "$jb_dir" -type f -mtime +"$CACHE_DAYS" 2>/dev/null | wc -l)
                    info "  [DRY-RUN] $usuario JetBrains: ${n} archivo(s) en $(basename "$jb_dir")"
                else
                    timeout 30 find "$jb_dir" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                    timeout 30 find "$jb_dir" -type d -empty -delete 2>/dev/null || true
                fi
            fi
        done
    done < <(_dev_user_homes)

    if [[ "$found" == false ]]; then
        info "  Sin IDEs detectados (VS Code/JetBrains), omitido"
    else
        ok "Caché de IDEs limpiada"
    fi
}
