#!/bin/bash
# Execution helpers: run_tolerant, run_critical, run_probe, run_with_timeout

run_tolerant() {
    local desc="$1"; shift
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
        return 0
    fi

    local secs=""
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        secs="$1"; shift
    fi

    local output
    if [[ -n "$secs" ]]; then
        if output=$(timeout "$secs" "$@" 2>&1); then
            printf "%s" "$output"
            return 0
        else
            local rc=$?
            local msg; msg=$(printf "%s" "$output" | head -n1)
            if [[ "$rc" -eq 124 ]]; then
                warn "Timeout — ${desc}: ${msg:-sin detalle}"
                report_timeout "$desc"
            else
                warn "No crítico — ${desc}: ${msg:-sin detalle}"
                report_warn "$desc"
            fi
            ERRORES_NO_CRITICOS+=("$desc")
            return 0
        fi
    else
        if output=$("$@" 2>&1); then
            printf "%s" "$output"
            return 0
        else
            local rc=$?
            local msg; msg=$(printf "%s" "$output" | head -n1)
            warn "No crítico — ${desc}: ${msg:-sin detalle}"
            report_warn "$desc"
            ERRORES_NO_CRITICOS+=("$desc")
            return 0
        fi
    fi
}

# Run a command but treat failures as critical (return non-zero).
# Usage: run_critical "description" cmd args...
run_critical() {
    local desc="$1"; shift
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
        return 0
    fi
    if "$@"; then
        return 0
    else
        local rc=$?
        err "Crítico — ${desc}: rc=${rc}"
        report_error "$desc"
        return $rc
    fi
}

# Probe a command: run it but ignore errors (used for probes like `docker info`).
# Usage: run_probe "description" cmd args...
run_probe() {
    local desc="$1"; shift
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
        return 0
    fi
    if "$@" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Simple helper: run a command normally or print it in DRY-RUN (no reporting).
# Usage: maybe_run cmd args...
maybe_run() {
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

# Helper to run a command with an enforced timeout in seconds.
# Usage: run_with_timeout 10 "description" cmd args...
run_with_timeout() {
    local secs="$1"; shift
    local desc="$1"; shift
    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] timeout ${secs}s $*"
        return 0
    fi
    local output
    if output=$(timeout "${secs}" "$@" 2>&1); then
        printf "%s" "$output"
        return 0
    else
        local rc=$?
        local msg
        msg=$(printf "%s" "$output" | head -n1)
        if [[ "$rc" -eq 124 ]]; then
            warn "Timeout — ${desc}: ${msg:-sin detalle}"
            report_timeout "$desc"
        else
            warn "No crítico — ${desc}: ${msg:-sin detalle}"
            report_warn "$desc"
        fi
        ERRORES_NO_CRITICOS+=("$desc")
        printf "%s" "$output"
        return $rc
    fi
}

# Centralized DRY_RUN handler: eliminates if/else duplication in modules.
# In DRY_RUN mode: shows preview text.
# In real mode: executes command with run_tolerant.
# Usage: previewable_run "description" "preview text to show" cmd arg1 arg2
# Example: previewable_run "apt clean" "apt-get clean" apt-get clean
previewable_run() {
    local desc="$1"; shift
    local preview_text="$1"; shift

    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "  [DRY-RUN] $preview_text"
        return 0
    fi

    run_tolerant "$desc" "$@"
}
