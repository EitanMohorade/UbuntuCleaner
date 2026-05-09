#!/bin/bash
# Space measurement helpers: get_used_bytes, get_space_breakdown, format_bytes

get_used_bytes() {
    df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay --output=used 2>/dev/null \
        | tail -n +2 \
        | tr -d ' ' \
        | awk 'NF && /^[0-9]+$/ {s += $1} END {print (s ? s : 0)}'
}

get_space_breakdown() {
    df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay \
        --output=target,used 2>/dev/null \
        | tail -n +2
}

format_bytes() {
    local bytes="$1"
    if   (( bytes < 1024 ));              then echo "${bytes} B"
    elif (( bytes < 1024 * 1024 ));       then awk "BEGIN{printf \"%.1f KB\", $bytes/1024}"
    elif (( bytes < 1024 * 1024 * 1024)); then awk "BEGIN{printf \"%.1f MB\", $bytes/1024/1024}"
    else                                       awk "BEGIN{printf \"%.2f GB\", $bytes/1024/1024/1024}"
    fi
}

format_space_change() {
    local bytes="$1"
    if (( bytes > 0 )); then
        echo "$(format_bytes "$bytes") liberados"
    elif (( bytes < 0 )); then
        echo "aumentó el uso en $(format_bytes $(( -bytes )))"
    else
        echo "0 B sin cambio"
    fi
}
