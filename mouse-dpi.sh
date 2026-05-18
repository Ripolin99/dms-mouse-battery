#!/usr/bin/env bash
# mouse-dpi.sh — backend wrapper for reading and changing mouse DPI.
#
# Supports two backends:
#   - solaar     (Logitech HID++, paquet "solaar")
#   - ratbagctl  (libratbag, paquet "libratbag" + service "ratbagd")
#
# Usage:
#   mouse-dpi.sh detect              -> prints backend in use (solaar|ratbagctl|none)
#   mouse-dpi.sh range               -> prints "min max step" for the active device
#   mouse-dpi.sh get                 -> prints current DPI (integer) or empty
#   mouse-dpi.sh set <value>         -> sets DPI to <value>
#
# Environment overrides:
#   MOUSE_DPI_BACKEND   force "solaar" or "ratbagctl"
#   MOUSE_DPI_DEVICE    pass an explicit device identifier (solaar device index/name, or ratbagctl short name)

set -u

cmd="${1:-detect}"
shift || true

backend="${MOUSE_DPI_BACKEND:-}"
device="${MOUSE_DPI_DEVICE:-}"

detect_backend() {
    if [ -n "$backend" ]; then
        echo "$backend"
        return
    fi
    if command -v solaar >/dev/null 2>&1; then
        echo "solaar"
        return
    fi
    if command -v ratbagctl >/dev/null 2>&1; then
        echo "ratbagctl"
        return
    fi
    echo "none"
}

# Pick the first ratbag device short-name from `ratbagctl list`
ratbagctl_device() {
    if [ -n "$device" ]; then
        echo "$device"
        return
    fi
    ratbagctl list 2>/dev/null | head -n1 | cut -d: -f1
}

# For solaar, the simplest stable identifier is the device index on the receiver (defaults to 1)
solaar_device() {
    if [ -n "$device" ]; then
        echo "$device"
        return
    fi
    echo "1"
}

# Parse "dpi: 800 (default: 800)" or similar Solaar output -> integer
solaar_parse_int() {
    grep -oE '[0-9]+' | head -n1
}

# Solaar's `solaar config` CLI is buggy for the dpi_extended keyed setting when
# the GUI daemon isn't running: it fails to validate keys it didn't just set.
# We use a Python wrapper that reads the current value first and handles
# onboard-profile interference automatically.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
SOLAAR_PY="$SCRIPT_DIR/solaar-dpi.py"

solaar_py_args() {
    local d
    d=$(solaar_device)
    if [ -n "$d" ] && [ "$d" != "1" ] || [ -n "$device" ]; then
        echo "--device $(printf %q "$d")"
    fi
}

solaar_get() {
    local extra
    extra=$(solaar_py_args)
    eval "python3 \"$SOLAAR_PY\" get $extra" 2>/dev/null
}

solaar_range() {
    local extra
    extra=$(solaar_py_args)
    eval "python3 \"$SOLAAR_PY\" range $extra" 2>/dev/null
}

solaar_set() {
    local extra
    extra=$(solaar_py_args)
    eval "python3 \"$SOLAAR_PY\" set \"$1\" $extra" >&2
}

ratbag_get() {
    local d
    d=$(ratbagctl_device)
    [ -z "$d" ] && return 1
    ratbagctl "$d" dpi get 2>/dev/null | grep -oE '[0-9]+' | head -n1
}

ratbag_range() {
    local d
    d=$(ratbagctl_device)
    [ -z "$d" ] && { echo "400 6400 50"; return; }
    # `ratbagctl <dev> resolution capabilities` or `dpi get-all` -> we use `dpi capabilities` if available.
    local values
    values=$(ratbagctl "$d" dpi capabilities 2>/dev/null | grep -oE '[0-9]+' | sort -n | uniq)
    if [ -z "$values" ]; then
        echo "400 6400 50"
        return
    fi
    local min max step
    min=$(echo "$values" | head -n1)
    max=$(echo "$values" | tail -n1)
    step=$(echo "$values" | awk 'NR>1 { d=$1-prev; if (d>0 && (min==0 || d<min)) min=d } { prev=$1 } END { print (min>0?min:50) }')
    echo "$min $max $step"
}

ratbag_set() {
    local d
    d=$(ratbagctl_device)
    [ -z "$d" ] && return 1
    ratbagctl "$d" dpi set "$1" >/dev/null 2>&1
}

backend=$(detect_backend)

case "$cmd" in
    detect)
        echo "$backend"
        ;;
    range)
        case "$backend" in
            solaar)    solaar_range ;;
            ratbagctl) ratbag_range ;;
            *)         echo "400 6400 50" ;;
        esac
        ;;
    get)
        case "$backend" in
            solaar)    solaar_get ;;
            ratbagctl) ratbag_get ;;
            *)         echo "" ;;
        esac
        ;;
    set)
        val="${1:-}"
        if [ -z "$val" ]; then
            echo "missing value" >&2
            exit 2
        fi
        case "$backend" in
            solaar)    solaar_set "$val" ;;
            ratbagctl) ratbag_set "$val" ;;
            *) echo "no backend (install solaar or libratbag)" >&2; exit 3 ;;
        esac
        ;;
    *)
        echo "usage: $0 {detect|range|get|set <value>}" >&2
        exit 2
        ;;
esac
