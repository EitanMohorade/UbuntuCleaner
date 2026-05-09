#!/bin/bash
# Reporting arrays and helpers (semantic events)

declare -a REPORT_OKS=()
declare -a REPORT_WARNS=()
declare -a REPORT_ERRORS=()
declare -a REPORT_TIMEOUTS=()
declare -a REPORT_SKIPS=()

report_ok() { REPORT_OKS+=("$1"); }
report_warn() { REPORT_WARNS+=("$1"); }
report_error() { REPORT_ERRORS+=("$1"); }
report_timeout() { REPORT_TIMEOUTS+=("$1"); }
report_skip() { REPORT_SKIPS+=("$1"); }

# Non-critical errors collector
ERRORES_NO_CRITICOS=()

_json_array_from_name() {
    local -n arr_ref="$1"
    local items=""
    for item in "${arr_ref[@]:-}"; do
        [[ -z "$item" ]] && continue
        items+="\"${item}\"," 
    done
    echo "[${items%,}]"
}
