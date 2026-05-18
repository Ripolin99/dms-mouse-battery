#!/usr/bin/env bash
# battery-query.sh — find the first UPower device of a given type and emit key=value pairs.
#
# Usage:
#   battery-query.sh <type>
#     <type>: "mouse", "gaming-input", "keyboard", "headset", ... (a section header in `upower -i`)
#
# Output (stdout, one key=value per line, empty if no device found):
#   path=<dbus path>
#   model=<model string>
#   percentage=<integer>
#   state=<discharging|charging|fully-charged|pending-charge|...>
#   present=<yes|no>
#   icon=<upower icon name>

set -u

type="${1:-mouse}"

if ! command -v upower >/dev/null 2>&1; then
    exit 0
fi

# Iterate every device, stop at the first matching <type> section header.
while IFS= read -r path; do
    [ -z "$path" ] && continue
    info=$(upower -i "$path" 2>/dev/null) || continue
    if printf '%s\n' "$info" | grep -qE "^  ${type}$"; then
        printf 'path=%s\n' "$path"
        printf '%s\n' "$info" | awk -F: '
            /^  model:/        { sub(/^  model: */, "");        print "model=" $0 }
            /^    percentage:/ { sub(/^.*percentage: */, "");   sub(/%.*/, ""); print "percentage=" $0 }
            /^    state:/      { sub(/^.*state: */, "");        print "state=" $0 }
            /^    present:/    { sub(/^.*present: */, "");      print "present=" $0 }
            /^    icon-name:/  { sub(/^.*icon-name: */, "");    gsub(/[\x27"]/, ""); print "icon=" $0 }
        '
        exit 0
    fi
done < <(upower -e 2>/dev/null)
