#!/bin/bash
# Limpieza de Docker.

_dev_docker() {
    if ! run_probe "docker available" command -v docker; then
        info "Docker no instalado, omitido"
        report_skip "dev/docker: no instalado"
        return 0
    fi

    if ! run_probe "docker daemon active" docker info; then
        warn "Docker instalado pero daemon no activo (skipping)"
        report_warn "dev/docker: daemon no activo"
        return 0
    fi

    info "Limpiando recursos Docker..."

    if [[ "${DRY_RUN:-false}" == true ]]; then
        local containers
        containers=$(run_with_timeout 30 "dev/docker: conteo containers" docker ps -aq --filter status=exited | wc -l)
        local images
        images=$(run_with_timeout 30 "dev/docker: conteo images" docker images -qf dangling=true | wc -l)
        local volumes
        volumes=$(run_with_timeout 30 "dev/docker: conteo volumes" docker volume ls -qf dangling=true | wc -l)
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
        report_skip "dev/docker: volume prune deshabilitado"
    fi

    ok "Docker limpio"
    report_ok "dev/docker: limpieza completada"
}
