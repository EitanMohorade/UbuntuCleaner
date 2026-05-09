#!/bin/bash
# Logging utilities (colors + simple logger)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

_log() {
    local line="$*"
    echo -e "$line"
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}

ok()   { _log "${GREEN}  ✔ $*${RESET}"; }
info() { _log "${CYAN}  → $*${RESET}"; }
warn() { _log "${YELLOW}  ⚠ $*${RESET}"; }
err()  { _log "${RED}  ✘ $*${RESET}"; }
step() { _log "\n${BOLD}[$1] $2${RESET}"; }
