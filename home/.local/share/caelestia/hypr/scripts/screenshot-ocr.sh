#!/usr/bin/env bash
# Select a screen region, OCR it, and open recognized text in an editor.

set -euo pipefail

notify() {
    notify-send -t 2500 -i edit-copy "Screenshot OCR" "$1"
}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        notify "Missing '$1'. Install tesseract + language data first."
        exit 1
    fi
}

need grim
need slurp
need tesseract

geometry=$(slurp) || exit 0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

shot="$tmpdir/shot.png"
ocr_input="$tmpdir/ocr.png"

grim -g "$geometry" "$shot"

if command -v magick >/dev/null 2>&1; then
    magick "$shot" -colorspace Gray -resize 250% -sharpen 0x1 "$ocr_input"
else
    ocr_input="$shot"
fi

langs=$(tesseract --list-langs 2>/dev/null | tail -n +2 || true)
lang="eng"
if grep -qx "tha" <<<"$langs"; then
    lang="eng+tha"
fi

clean_text() {
    perl -CSDA -0pe '
        s/[ \t]+\n/\n/g;
        s/\n[ \t]+/\n/g;
        s/([\x{0E00}-\x{0E7F}])[ \t]+(?=[\x{0E00}-\x{0E7F}])/$1/g;
        s/[ \t]+\z//;
    '
}

text=$(tesseract "$ocr_input" stdout -l "$lang" --psm 6 2>/dev/null | clean_text) || {
    notify "OCR failed."
    exit 1
}

if [[ -z "$text" ]]; then
    notify "No text found."
    exit 0
fi

out="${XDG_RUNTIME_DIR:-/tmp}/screenshot-ocr-$(date +%Y%m%d-%H%M%S).txt"
printf '%s\n' "$text" > "$out"

if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$text" | wl-copy
fi

if command -v zeditor >/dev/null 2>&1; then
    app2unit -- zeditor --new "$out" >/dev/null 2>&1 &
elif command -v kate >/dev/null 2>&1; then
    kate --new "$out" >/dev/null 2>&1 &
elif command -v code >/dev/null 2>&1; then
    code --new-window "$out" >/dev/null 2>&1 &
elif command -v foot >/dev/null 2>&1 && command -v nvim >/dev/null 2>&1; then
    foot --title "Screenshot OCR" nvim "$out" >/dev/null 2>&1 &
else
    need wl-copy
    printf '%s' "$text" | wl-copy
    notify "No editor found. Copied all OCR text to clipboard."
    exit 0
fi

notify "Copied OCR text and opened it in Zed."
