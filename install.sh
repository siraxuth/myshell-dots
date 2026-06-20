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
  say "Installing AUR packages (caelestia + mpvpaper)"
  "$AUR" -S --needed --noconfirm caelestia-shell-git caelestia-cli-git mpvpaper || \
    warn "AUR install failed — install caelestia-shell-git, caelestia-cli-git, mpvpaper manually."
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
