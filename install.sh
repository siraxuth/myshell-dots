#!/usr/bin/env bash
# myshell-dots installer — customized Caelestia (Hyprland + Quickshell) desktop.
# Safe to re-run: it backs up anything it would overwrite to <path>.bak.<timestamp>.
#
#   ./install.sh            # packages + configs + symlinks
#   ./install.sh --no-pkg   # configs + symlinks only (skip package install)
set -euo pipefail

DOTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTS/home"
STAMP="$(date +%Y%m%d-%H%M%S)"
NO_PKG=0
[ "${1:-}" = "--no-pkg" ] && NO_PKG=1

say()  { printf '\033[1;32m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

backup_and_place() {
  # $1 = path under $SRC (e.g. .config/caelestia), placed at $HOME/$1
  local rel="$1" dst="$HOME/$1"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    warn "backup: $dst -> $dst.bak.$STAMP"
    mv "$dst" "$dst.bak.$STAMP"
  fi
  cp -r "$SRC/$rel" "$dst"
}

# ----------------------------------------------------------------------------
# 1. Packages (Arch / CachyOS). On anything else, skip — see README (NixOS etc.)
# ----------------------------------------------------------------------------
if [ "$NO_PKG" = 0 ] && command -v pacman >/dev/null 2>&1; then
  say "Installing repo packages (pacman)"
  grep -vE '^\s*#|^\s*$' "$DOTS/packages.txt" | sudo pacman -S --needed --noconfirm - || \
    warn "Some pacman packages failed — continuing."

  AUR="$(command -v yay || command -v paru || true)"
  if [ -z "$AUR" ]; then
    say "No AUR helper found — bootstrapping yay"
    sudo pacman -S --needed --noconfirm git base-devel
    tmp="$(mktemp -d)"; git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm )
    AUR="$(command -v yay)"
  fi
  say "Installing AUR packages (caelestia + mpvpaper + apps)"
  "$AUR" -S --needed --noconfirm caelestia-shell-git caelestia-cli-git mpvpaper \
    visual-studio-code-bin zen-browser-bin || \
    warn "Some AUR installs failed — install caelestia-shell-git, caelestia-cli-git, mpvpaper, visual-studio-code-bin, zen-browser-bin manually."

  # Optional: Div-Acer-Manager-Max (Acer laptops only — fan/perf control)
  if [ -t 0 ]; then
    read -rp ":: Install Div-Acer-Manager-Max (Acer laptops only)? [y/N] " _damx
    if [[ "${_damx:-}" =~ ^[Yy] ]]; then
      tmp="$(mktemp -d)"
      git clone --depth=1 https://github.com/PXDiv/Div-Acer-Manager-Max.git "$tmp/damx" \
        && ( cd "$tmp/damx" && { [ -x ./install.sh ] && ./install.sh || bash ./install.sh; } ) \
        || warn "DAMX install failed — grab it from github.com/PXDiv/Div-Acer-Manager-Max/releases"
    fi
  else
    warn "Non-interactive run — skipping optional Div-Acer-Manager-Max (Acer-only)."
  fi
elif [ "$NO_PKG" = 0 ]; then
  warn "pacman not found — skipping packages. This config targets Arch/CachyOS."
  warn "On NixOS: declare the packages in configuration.nix (see README) and run with --no-pkg."
fi

# ----------------------------------------------------------------------------
# 2. Place config trees
# ----------------------------------------------------------------------------
say "Placing configs (existing ones are backed up)"
backup_and_place ".local/share/caelestia"
backup_and_place ".config/quickshell/caelestia"
backup_and_place ".config/caelestia"

# ----------------------------------------------------------------------------
# 3. Recreate the Caelestia symlinks ~/.config/* -> ~/.local/share/caelestia/*
# ----------------------------------------------------------------------------
say "Linking ~/.config entries to the Caelestia data dir"
link() {
  local name="$1" target="$HOME/.local/share/caelestia/$1" dst="$HOME/.config/$1"
  [ -e "$target" ] || { warn "skip $name (no $target)"; return; }
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ "$(readlink -f "$dst" 2>/dev/null)" != "$(readlink -f "$target")" ]; then
    mv "$dst" "$dst.bak.$STAMP"
  fi
  ln -sfn "$target" "$dst"
}
for n in btop fastfetch fish foot hypr uwsm starship.toml; do link "$n"; done

# App configs that don't live under ~/.config directly (VSCode / Zed / Thunar / Zen)
say "Linking app configs (VSCode / Zed / Thunar / Zen)"
CAEL="$HOME/.local/share/caelestia"
linkfile() { mkdir -p "$(dirname "$2")"; ln -sfn "$1" "$2"; }
if [ -f "$CAEL/vscode/settings.json" ]; then
  linkfile "$CAEL/vscode/settings.json"    "$HOME/.config/Code/User/settings.json"
  linkfile "$CAEL/vscode/keybindings.json" "$HOME/.config/Code/User/keybindings.json"
  linkfile "$CAEL/vscode/flags.conf"       "$HOME/.config/code-flags.conf"
fi
if [ -f "$CAEL/zed/settings.json" ]; then
  linkfile "$CAEL/zed/settings.json" "$HOME/.config/zed/settings.json"
  linkfile "$CAEL/zed/keymap.json"   "$HOME/.config/zed/keymap.json"
fi
if [ -f "$CAEL/thunar/uca.xml" ]; then
  linkfile "$CAEL/thunar/uca.xml"           "$HOME/.config/Thunar/uca.xml"
  linkfile "$CAEL/thunar/thunar-volman.xml" "$HOME/.config/Thunar/thunar-volman.xml"
fi
# Zen userChrome — only if a profile already exists (run zen once first, set toolkit.legacyUserProfileCustomizations.stylesheets=true)
for prof in "$HOME"/.zen/*/; do
  [ -d "$prof" ] && [ -f "$CAEL/zen/userChrome.css" ] && linkfile "$CAEL/zen/userChrome.css" "${prof}chrome/userChrome.css"
done

# ----------------------------------------------------------------------------
# 4. Live wallpaper folder
# ----------------------------------------------------------------------------
mkdir -p "$HOME/Videos/Wallpapers"
say "Drop .mp4/.webm files in ~/Videos/Wallpapers for the Super+Shift+W picker."

cat <<EOF

$(say "Done.")
Next steps:
  • Log into Hyprland (uwsm session) — the shell autostarts via exec-once.
  • If the bar/shell isn't up:   qs -c caelestia kill; caelestia shell -d
  • Restart shell after edits:    Ctrl+Super+Alt+R   (qs 0.3.0 has no hot-reload)
  • Read BUGS.md for every known gotcha + the exact command to fix it.
EOF
