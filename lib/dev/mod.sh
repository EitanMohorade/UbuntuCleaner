#!/bin/bash
# Orquestador del modulo DEV.

run_dev() {
    step "DEV" "Limpieza de entorno de desarrollo"

    _dev_docker
    _dev_virtualization
    _dev_ides
    _dev_package_managers
    _dev_databases
}
