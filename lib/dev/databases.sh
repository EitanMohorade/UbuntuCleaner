#!/bin/bash
# Limpieza de logs de bases de datos.

_dev_databases() {
    info "  [DEBUG] Entrando a _dev_databases"
    info "Limpiando logs de bases de datos..."
    local found=false

    info "  [DEBUG] Chequeando PostgreSQL..."
    if command -v psql &>/dev/null; then
        found=true
        info "  [DEBUG] PostgreSQL detectado, usando pg_lsclusters..."
        if command -v pg_lsclusters &>/dev/null; then
            timeout 5 pg_lsclusters --no-header 2>/dev/null | awk '{print $1, $2, $6}' | \
            while read -r pg_ver pg_name pg_datadir; do
                info "  [DEBUG] Procesando cluster PostgreSQL: $pg_ver/$pg_name"
                local pg_log="${pg_datadir}/log"
                if [[ ! -d "$pg_log" ]]; then
                    pg_log="${pg_datadir}/pg_log"
                fi

                if [[ -d "$pg_log" ]]; then
                    if [[ "${DRY_RUN:-false}" == true ]]; then
                        local n
                        n=$(timeout 30 find "$pg_log" -type f -mtime +"${LOG_DAYS}" 2>/dev/null | wc -l)
                        info "  [DRY-RUN] PostgreSQL $pg_ver/$pg_name: ${n} log(s) a eliminar"
                    else
                        run_tolerant "limpiar logs PostgreSQL $pg_ver/$pg_name" \
                            timeout 30 find "$pg_log" -type f -mtime +"${LOG_DAYS}" -delete
                        ok "Logs de PostgreSQL $pg_ver/$pg_name depurados"
                    fi
                fi
            done
        fi
    fi

    info "  [DEBUG] Chequeando MySQL/MariaDB..."
    for sock in /var/run/mysqld/mysqld.sock /var/run/mysqld/mariadbd.sock; do
        info "  [DEBUG] Verificando socket: $sock"
        if [[ -S "$sock" ]]; then
            found=true
            if [[ "${DRY_RUN:-false}" == true ]]; then
                info "  [DRY-RUN] MySQL/MariaDB: PURGE BINARY LOGS BEFORE NOW() - ${LOG_DAYS}d"
            else
                run_tolerant "MySQL purge binary logs" \
                    timeout 10 mysql \
                        --connect-timeout=5 \
                        --batch \
                        --skip-column-names \
                        -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL ${LOG_DAYS} DAY);" \
                        </dev/null
                ok "MySQL/MariaDB binary logs depurados"
            fi
            break
        fi
    done

    if [[ "$found" == false ]]; then
        info "  Sin bases de datos detectadas, omitido"
    fi
}
