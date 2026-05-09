#!/bin/bash
# Limpieza de Docker.

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
        local images; images=$(docker images -qf dangling=true 2>/dev/null | wc -l)
        local volumes; volumes=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l)
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
