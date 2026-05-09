#!/bin/bash
# Limpieza de logs de bases de datos.

_dev_databases() {
    info "Limpiando logs de bases de datos..."
    local found=false
    
    if run_probe "psql available" command -v psql; then
        found=true
        info "  PostgreSQL detectado, usando pg_lsclusters..."
        if run_probe "pg_lsclusters available" command -v pg_lsclusters; then
            local pg_list
            pg_list=$(run_with_timeout 5 "pg_lsclusters" pg_lsclusters --no-header) || pg_list=""
            printf "%s" "$pg_list" | awk '{print $1, $2, $6}' | \
            while read -r pg_ver pg_name pg_datadir; do
                info "  Procesando cluster PostgreSQL: $pg_ver/$pg_name"
                local pg_log="${pg_datadir}/log"
                [[ ! -d "$pg_log" ]] && pg_log="${pg_datadir}/pg_log"

                if [[ -d "$pg_log" ]]; then
                    if [[ "${DRY_RUN:-false}" == true ]]; then
                        local output n
                        output=$(run_with_timeout 30 "dev/databases: conteo $pg_log" find "$pg_log" -type f -mtime +"${LOG_DAYS}")
                        n=$(printf "%s" "$output" | wc -l)
                        info "  [DRY-RUN] PostgreSQL $pg_ver/$pg_name: ${n} log(s) a eliminar"
                    else
                        previewable_run "limpiar logs PostgreSQL $pg_ver/$pg_name" \
                            "find $pg_log -type f -mtime +${LOG_DAYS} -delete" \
                            find "$pg_log" -type f -mtime +"${LOG_DAYS}" -delete
                        ok "Logs de PostgreSQL $pg_ver/$pg_name depurados"
                    fi
                fi
            done
        fi
    fi

    info "  Chequeando MySQL/MariaDB..."
    for sock in /var/run/mysqld/mysqld.sock /var/run/mysqld/mariadbd.sock; do
        info "  Verificando socket: $sock"
        if [[ -S "$sock" ]]; then
            found=true
            previewable_run "MySQL purge binary logs" \
                "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL ${LOG_DAYS} DAY)" \
                mysql --connect-timeout=5 --batch --skip-column-names \
                -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL ${LOG_DAYS} DAY);" \
                </dev/null
            if [[ "${DRY_RUN:-false}" != true ]]; then
                ok "MySQL/MariaDB binary logs depurados"
            fi
            break
        fi
    done

    if [[ "$found" == false ]]; then
        info "  Sin bases de datos detectadas, omitido"
        report_skip "dev/databases: sin bases de datos detectadas"
    else
        report_ok "dev/databases: limpieza completada"
    fi
}
