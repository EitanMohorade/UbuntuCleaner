#!/bin/bash
# Utilidades compartidas del modulo DEV.

_dev_user_homes() {
    for home_dir in /home/*/; do
        if [[ ! -d "$home_dir" ]]; then
            continue
        fi

        local usuario
        usuario=$(basename "$home_dir")
        if [[ "$usuario" == "lost+found" ]]; then
            continue
        fi

        printf '%s\t%s\n' "$home_dir" "$usuario"
    done
}
