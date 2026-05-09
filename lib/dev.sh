#!/bin/bash
# Loader del modulo DEV dividido en submodulos.

if [[ -z "${ROOT_DIR:-}" ]]; then
    DEV_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT_DIR="$(dirname "$DEV_SH_DIR")"
fi

source "${ROOT_DIR}/lib/dev/common.sh"
source "${ROOT_DIR}/lib/dev/docker.sh"
source "${ROOT_DIR}/lib/dev/virtualization.sh"
source "${ROOT_DIR}/lib/dev/ides.sh"
source "${ROOT_DIR}/lib/dev/package_managers.sh"
source "${ROOT_DIR}/lib/dev/databases.sh"
source "${ROOT_DIR}/lib/dev/mod.sh"