#!/usr/bin/env bash
# Screenshot picker -> clipboard. Menu via fuzzel.
# Options: region, all screens, or a specific monitor.

set -euo pipefail

copy_notify() {
    # stdin = png bytes
    wl-copy
    notify-send -t 2000 -i image-x-generic "Screenshot" "$1 -> clipboard"
}

# Build dynamic monitor entries: "  HDMI-A-2  (DHI LM25-B221B)"
mapfile -t MONS < <(hyprctl monitors -j | jq -r '.[] | "\(.name)\t\(.description)"')

# Menu options
options="Region (select area)
All screens"
for m in "${MONS[@]}"; do
    name="${m%%$'\t'*}"
    desc="${m#*$'\t'}"
    options+=$'\n'"Monitor: ${name}  (${desc})"
done

choice=$(printf '%s' "$options" | fuzzel --dmenu --prompt "📷 Screenshot > " --lines 8 --width 40) || exit 0

case "$choice" in
    "Region"*)
        grimblast --freeze save area - | copy_notify "Region"
        ;;
    "All screens")
        grimblast save screen - | copy_notify "All screens"
        ;;
    "Monitor: "*)
        rest="${choice#Monitor: }"
        name="${rest%%  (*}"
        grim -o "$name" - | copy_notify "$name"
        ;;
    *)
        exit 0
        ;;
esac
