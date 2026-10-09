#!/usr/bin/env bash
# First-run bootstrap for myshell-dots. The full installer runs from the cloned repo.
set -euo pipefail

REPO_URL="https://github.com/siraxuth/myshell-dots.git"
INSTALL_DIR="${MYSHELL_DOTS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/myshell-dots}"

say() { printf '\033[1;32m::\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || fail "git is required. Install git, then rerun this command."

if [ -d "$INSTALL_DIR/.git" ]; then
  say "Updating existing checkout at $INSTALL_DIR"
  git -C "$INSTALL_DIR" fetch --quiet origin main
  git -C "$INSTALL_DIR" pull --ff-only origin main
elif [ -e "$INSTALL_DIR" ]; then
  fail "$INSTALL_DIR exists but is not a Git checkout. Move it aside or set MYSHELL_DOTS_DIR."
else
  say "Downloading myshell-dots to $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --depth 1 --branch main "$REPO_URL" "$INSTALL_DIR"
fi

[ -x "$INSTALL_DIR/install.sh" ] || fail "Installer not found at $INSTALL_DIR/install.sh"
exec "$INSTALL_DIR/install.sh" "$@"
