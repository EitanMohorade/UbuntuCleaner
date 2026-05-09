#!/bin/bash
# State persistence: save_state and JSON export

save_state() {
    local state_file="$1"
    local space_before="$2"   # bytes
    local space_after="$3"    # bytes
    local modules_run="$4"
    local dry_run="${DRY_RUN:-false}"
    local freed=$(( space_before - space_after ))

    local warnings_json=""
    for e in "${ERRORES_NO_CRITICOS[@]:-}"; do
        [[ -z "$e" ]] && continue
        warnings_json+="\"${e}\"," 
    done
    warnings_json="[${warnings_json%,}]"

    local report_counts_json=""
    report_counts_json=$(cat <<EOF
    "report_counts": {
        "ok": ${#REPORT_OKS[@]},
        "warn": ${#REPORT_WARNS[@]},
        "error": ${#REPORT_ERRORS[@]},
        "timeout": ${#REPORT_TIMEOUTS[@]},
        "skip": ${#REPORT_SKIPS[@]}
    },
    "report_events": {
        "ok": $(_json_array_from_name REPORT_OKS),
        "warn": $(_json_array_from_name REPORT_WARNS),
        "error": $(_json_array_from_name REPORT_ERRORS),
        "timeout": $(_json_array_from_name REPORT_TIMEOUTS),
        "skip": $(_json_array_from_name REPORT_SKIPS)
    },
EOF
)

    local mods_json=""
    for m in $modules_run; do
        mods_json+="\"${m}\"," 
    done
    mods_json="[${mods_json%,}]"

    mkdir -p "$(dirname "$state_file")"
    cat > "$state_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "dry_run": ${dry_run},
  "space_before_bytes": ${space_before},
  "space_after_bytes": ${space_after},
  "space_freed_bytes": ${freed},
  "space_freed_human": "$(format_bytes $(( freed > 0 ? freed : 0 )))",
${report_counts_json}
  "modules_run": ${mods_json},
  "warnings": ${warnings_json}
}
EOF
}
