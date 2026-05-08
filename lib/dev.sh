#!/bin/bash
# lib/dev.sh — limpieza de entorno de desarrollo
# Las herramientas pueden no estar instaladas y los fallos no son críticos.

run_dev() {
    step "DEV" "Limpieza de entorno de desarrollo"

    _dev_docker
    _dev_vms
    _dev_ides
    _dev_package_managers
    _dev_databases
}

# ── Docker ───────────────────────────────────────────────────
_dev_docker() {
    if ! command -v docker &>/dev/null; then
        info "Docker no instalado, omitido"
        return 0
    fi

    if ! docker info &>/dev/null 2>&1; then
        warn "Docker instalado pero daemon no activo (skipping)"
        return 0
    fi

    info "Limpiando recursos Docker..."

    if [[ "${DRY_RUN:-false}" == true ]]; then
        local containers; containers=$(docker ps -aq --filter status=exited 2>/dev/null | wc -l)
        local images;     images=$(docker images -qf dangling=true 2>/dev/null | wc -l)
        local volumes;    volumes=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l)
        info "  [DRY-RUN] Containers detenidos: ${containers}"
        info "  [DRY-RUN] Imágenes dangling:    ${images}"
        info "  [DRY-RUN] Volúmenes huérfanos:  ${volumes}"
        return 0
    fi

    run_tolerant "docker container prune" docker container prune -f
    run_tolerant "docker image prune (dangling)" docker image prune -f
    run_tolerant "docker network prune" docker network prune -f
    run_tolerant "docker buildx prune" docker buildx prune -f

    if [[ "${ENABLE_DOCKER_VOLUME_PRUNE:-false}" == true ]]; then
        warn "Limpiando volúmenes Docker huérfanos (ENABLE_DOCKER_VOLUME_PRUNE=true)..."
        run_tolerant "docker volume prune" docker volume prune -f
    else
        info "  Volúmenes Docker: omitido (ENABLE_DOCKER_VOLUME_PRUNE=false por defecto)"
    fi

    ok "Docker limpio"
}

# ── VMs ──────────────────────────────────────────────────────
_dev_vms() {
    local found=false

    # libvirt
    if command -v virsh &>/dev/null; then
        found=true
        info "libvirt detectado..."

        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] Se limpiarían logs de libvirt en /var/log/libvirt/"
        else
            run_tolerant "limpiar logs libvirt" \
                find /var/log/libvirt -type f -name "*.log" -mtime +"${LOG_DAYS}" -delete
            ok "Logs de libvirt depurados"
        fi
    fi

    # VirtualBox
    if command -v vboxmanage &>/dev/null; then
        found=true
        info "VirtualBox detectado..."

        for home_dir in /home/*/; do
            [[ -d "$home_dir" ]] || continue
            local vbox_vms_dir="${home_dir}VirtualBox VMs"
            [[ -d "$vbox_vms_dir" ]] || continue

            # Los logs de VirtualBox están SIEMPRE en <VM>/Logs/.
            # No se necesita bajar más de 3 niveles:
            #   VirtualBox VMs/          → depth 0
            #     <NombreVM>/            → depth 1
            #       Logs/                → depth 2
            #         VBox.log           → depth 3
            #
            # Sin -maxdepth, find recorre también .vdi/.vmdk y árboles
            # de snapshots que pueden ser enormes → hang.
            # Sin -type f en el dry-run, puede intentar leer directorios
            # o archivos especiales → comportamiento indefinido.

            if [[ "${DRY_RUN:-false}" == true ]]; then
                local n; n=$(find "$vbox_vms_dir" \
                    -maxdepth 3 \
                    -type f \
                    \( -name "*.log" -o -name "*.log.*" \) \
                    -mtime +"${LOG_DAYS}" \
                    2>/dev/null | wc -l)
                info "  [DRY-RUN] VirtualBox: ${n} log(s) a eliminar"
            else
                run_tolerant "limpiar logs VirtualBox" \
                    find "$vbox_vms_dir" \
                        -maxdepth 3 \
                        -type f \
                        \( -name "*.log" -o -name "*.log.*" \) \
                        -mtime +"${LOG_DAYS}" \
                        -delete
                ok "Logs de VirtualBox depurados"
            fi
        done
    fi

    [[ "$found" == false ]] && info "Sin VMs detectadas (libvirt/VirtualBox), omitido"
}

# ── IDEs ─────────────────────────────────────────────────────
_dev_ides() {
    info "Limpiando caché de IDEs..."
    local found=false

    for home_dir in /home/*/; do
        [[ -d "$home_dir" ]] || continue
        local usuario; usuario=$(basename "$home_dir")

        # VS Code: solo logs y caché regenerable
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
                    local n; n=$(find "$vscode_dir" -type f -mtime +"$CACHE_DAYS" 2>/dev/null | wc -l)
                    info "  [DRY-RUN] $usuario VS Code: ${n} archivo(s) en $(basename "$vscode_dir")"
                else
                    find "$vscode_dir" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                    find "$vscode_dir" -type d -empty -delete 2>/dev/null || true
                fi
            fi
        done

        # JetBrains: caché y logs regenerables
        for jb_dir in \
            "${home_dir}.cache/JetBrains" \
            "${home_dir}.local/share/JetBrains"
        do
            if [[ -d "$jb_dir" ]]; then
                found=true
                if [[ "${DRY_RUN:-false}" == true ]]; then
                    local n; n=$(find "$jb_dir" -type f -mtime +"$CACHE_DAYS" 2>/dev/null | wc -l)
                    info "  [DRY-RUN] $usuario JetBrains: ${n} archivo(s) en $(basename "$jb_dir")"
                else
                    find "$jb_dir" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
                    find "$jb_dir" -type d -empty -delete 2>/dev/null || true
                fi
            fi
        done
    done

    if [[ "$found" == false ]]; then
        info "  Sin IDEs detectados (VS Code/JetBrains), omitido"
    else
        ok "Caché de IDEs limpiada"
    fi
}

# ── Package managers ──────────────────────────────────────────
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

    if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
        found=true
        local pip_cmd; pip_cmd=$(command -v pip3 || command -v pip)
        if [[ "${DRY_RUN:-false}" == true ]]; then
            info "  [DRY-RUN] pip cache purge"
        else
            run_tolerant "pip cache purge" "$pip_cmd" cache purge
            ok "Caché pip limpiada"
        fi
    fi

    for home_dir in /home/*/; do
        [[ -d "${home_dir}.gradle/caches" ]] || continue
        found=true
        local usuario; usuario=$(basename "$home_dir")
        if [[ "${DRY_RUN:-false}" == true ]]; then
            local size; size=$(du -sh "${home_dir}.gradle/caches" 2>/dev/null | cut -f1)
            info "  [DRY-RUN] $usuario Gradle cache: ${size} (archivos >$CACHE_DAYS días)"
        else
            find "${home_dir}.gradle/caches" -type f -mtime +"$CACHE_DAYS" -delete 2>/dev/null || true
            find "${home_dir}.gradle/caches" -type d -empty -delete 2>/dev/null || true
            ok "Gradle cache de '$usuario' limpiada"
        fi
    done

    for home_dir in /home/*/; do
        [[ -d "${home_dir}.m2/repository" ]] || continue
        found=true
        local usuario; usuario=$(basename "$home_dir")
        if [[ "${DRY_RUN:-false}" == true ]]; then
            local size; size=$(du -sh "${home_dir}.m2/repository" 2>/dev/null | cut -f1)
            info "  [DRY-RUN] $usuario Maven repo: ${size} (solo se informa, no se limpia automáticamente)"
        else
            # Conserva releases y borra solo snapshots viejos
            find "${home_dir}.m2/repository" -type f \
                -path "*-SNAPSHOT*" -mtime +"$CACHE_DAYS" \
                -delete 2>/dev/null || true
            ok "Maven snapshots viejos de '$usuario' eliminados"
        fi
    done

    [[ "$found" == false ]] && info "  Sin package managers detectados, omitido"
}

# ── Bases de datos ────────────────────────────────────────────
_dev_databases() {
    info "Limpiando logs de bases de datos..."
    local found=false

    if command -v psql &>/dev/null; then
        found=true
        if command -v pg_lsclusters &>/dev/null; then
            pg_lsclusters --no-header 2>/dev/null | awk '{print $1, $2, $6}' | \
            while read -r pg_ver pg_name pg_datadir; do
                local pg_log="${pg_datadir}/log"
                [[ -d "$pg_log" ]] || pg_log="${pg_datadir}/pg_log"
                if [[ -d "$pg_log" ]]; then
                    if [[ "${DRY_RUN:-false}" == true ]]; then
                        local n; n=$(find "$pg_log" -type f -mtime +"${LOG_DAYS}" 2>/dev/null | wc -l)
                        info "  [DRY-RUN] PostgreSQL $pg_ver/$pg_name: ${n} log(s) a eliminar"
                    else
                        run_tolerant "limpiar logs PostgreSQL $pg_ver/$pg_name" \
                            find "$pg_log" -type f -mtime +"${LOG_DAYS}" -delete
                        ok "Logs de PostgreSQL $pg_ver/$pg_name depurados"
                    fi
                fi
            done
        fi
    fi

    for sock in /var/run/mysqld/mysqld.sock /var/run/mysqld/mariadbd.sock; do
        if [[ -S "$sock" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                info "  [DRY-RUN] MySQL/MariaDB: PURGE BINARY LOGS BEFORE NOW() - ${LOG_DAYS}d"
            else
                run_tolerant "MySQL purge binary logs" \
                    mysql -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL ${LOG_DAYS} DAY);"
                ok "MySQL/MariaDB binary logs depurados"
            fi
            break
        fi
    done

    [[ "$found" == false ]] && info "  Sin bases de datos detectadas, omitido"
}