#!/bin/bash
# Core loader: source modular core helpers in lib/core/

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$LIB_DIR/core"

for f in "$CORE_DIR"/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
done
