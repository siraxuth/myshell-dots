#!/usr/bin/env bash
# Region select -> instant clipboard copy -> full editor window
# (big preview, draw/annotate tools, OCR text-select layer). All native
# GTK+WebKit, no qs/dunst in the loop.
set -euo pipefail

EDITOR_DIR="$HOME/.config/hypr/scripts/screenshot-editor"
CACHE_DIR="$HOME/.cache/caelestia/screenshots"

command -v slurp >/dev/null || exit 1
command -v grim >/dev/null || exit 1

freeze=false
cursor=false
snapshot=""
origin_x=0
origin_y=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --freeze)
            freeze=true
            shift
            ;;
        --cursor)
            cursor=true
            shift
            ;;
        --snapshot)
            snapshot="$2"
            shift 2
            ;;
        --origin-x)
            origin_x="$2"
            shift 2
            ;;
        --origin-y)
            origin_y="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p "$CACHE_DIR"

# Freeze the frame before slurp takes pointer focus. This preserves CSS
# :hover, menus and tooltips while the pointer is moved to select a region.
freeze_pid=""
hyprpicker_bin="$HOME/.local/bin/hyprpicker"
if [[ ! -x "$hyprpicker_bin" ]]; then
    hyprpicker_bin=$(command -v hyprpicker || true)
fi
if [[ -z "$snapshot" ]] && $freeze && [[ -n "$hyprpicker_bin" ]]; then
    freeze_args=(-r -z -q)
    $cursor && freeze_args+=(-c)
    "$hyprpicker_bin" "${freeze_args[@]}" >/dev/null 2>&1 &
    freeze_pid=$!
    sleep 0.22
    if ! kill -0 "$freeze_pid" 2>/dev/null; then
        freeze_pid=""
        freeze=false
    fi
fi

orig_pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ' || true)
restore_cursor=false
overlay_pid=""
ready_file=""
cleanup() {
    if [[ -n "$overlay_pid" ]]; then
        kill "$overlay_pid" 2>/dev/null || true
        wait "$overlay_pid" 2>/dev/null || true
    fi
    if [[ -n "$freeze_pid" ]]; then
        kill "$freeze_pid" 2>/dev/null || true
        wait "$freeze_pid" 2>/dev/null || true
    fi
    if $restore_cursor && [[ -n "$orig_pos" ]]; then
        hyprctl dispatch movecursor ${orig_pos/,/ } >/dev/null 2>&1 || true
    fi
    if [[ -n "$ready_file" ]]; then
        rm -f -- "$ready_file"
    fi
}
trap cleanup EXIT INT TERM

if [[ -n "$snapshot" ]]; then
    overlay="$HOME/.config/hypr/scripts/capture-dashboard/freeze_overlay.py"
    ready_file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/screenshot-freeze-ready.XXXXXX")
    rm -f -- "$ready_file"
    /usr/bin/python3 "$overlay" \
        --image "$snapshot" \
        --origin-x "$origin_x" \
        --origin-y "$origin_y" \
        --ready-file "$ready_file" &
    overlay_pid=$!
    for _ in {1..30}; do
        [[ -e "$ready_file" ]] && break
        kill -0 "$overlay_pid" 2>/dev/null || exit 1
        sleep 0.02
    done
fi

geometry=$(slurp) || exit 0

shot="$CACHE_DIR/$(date +%Y%m%d-%H%M%S).png"

if [[ -n "$snapshot" ]]; then
    read -r rx ry rw rh <<<"$(awk -F'[, x]+' '{print $1, $2, $3, $4}' <<<"$geometry")"
    crop_x=$((rx - origin_x))
    crop_y=$((ry - origin_y))
    magick "$snapshot" -crop "${rw}x${rh}+${crop_x}+${crop_y}" +repage "$shot"
else

    # grim's -c/no-c only toggles a hw-plane cursor overlay; with
    # no_hardware_cursors=true (needed by dynamic-cursors shake-to-find) the cursor
    # is baked into every frame regardless of the flag, so "hide" has to physically
    # park the cursor off the selected rect instead. When the frame is frozen, park
    # the live cursor for both modes: --cursor is already in the frozen preview at
    # the original hover point.
    grim_args=()
    if $cursor && ! $freeze; then
        grim_args+=(-c)
    fi
    if $freeze || ! $cursor; then
        read -r rx ry rw rh <<<"$(awk -F'[, x]+' '{print $1, $2, $3, $4}' <<<"$geometry")"
        park=$(hyprctl monitors -j | jq -r \
            --argjson rx "$rx" --argjson ry "$ry" --argjson rw "$rw" --argjson rh "$rh" '
            [ .[] as $m |
              [[$m.x + 8, $m.y + 8],
               [$m.x + $m.width - 8, $m.y + 8],
               [$m.x + 8, $m.y + $m.height - 8],
               [$m.x + $m.width - 8, $m.y + $m.height - 8],
               [$m.x + ($m.width / 2 | floor), $m.y + ($m.height / 2 | floor)]][] |
              select(.[0] < $rx or .[0] >= ($rx + $rw) or
                     .[1] < $ry or .[1] >= ($ry + $rh))
            ][0] | if . then "\(.[0]) \(.[1])" else empty end
        ')
        if [[ -n "$park" ]]; then
            hyprctl dispatch movecursor $park >/dev/null
            restore_cursor=true
            sleep 0.08
        fi
    fi
    grim "${grim_args[@]}" -g "$geometry" "$shot"
fi

# Instant paste-ready copy, before the editor window even opens.
wl-copy < "$shot"

# /usr/bin/python3 explicitly: pyenv shadows the system python that has
# PyGObject/GTK installed.
setsid /usr/bin/python3 "$EDITOR_DIR/editor.py" "$shot" >/dev/null 2>&1 &
disown
