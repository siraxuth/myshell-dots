# myshell-dots

My customized **Caelestia** desktop — Hyprland + Quickshell — packaged so a fresh machine
(or a move to CachyOS / NixOS) comes back up with the *exact same* config and no surprises.

Built on top of [caelestia-dots](https://github.com/caelestia-dots), with custom additions:

- **Launcher position** — top / center / bottom, switchable in *Control Center → Launcher Settings → Position*.
- **Launcher search bar** — top or bottom, independently switchable.
- **Center launcher animation** — pops/expands from the screen centre.
- **Live wallpaper picker** — `Super+Shift+W` opens a dashboard-style panel to pick a video
  wallpaper from `~/Videos/Wallpapers/`. Arrow keys preview live (debounced), Enter applies,
  Esc reverts. Driven by `mpvpaper`; the shell never decodes video itself.
- Thai-layout-safe keybinds, hybrid-GPU fix, boot-race fix, and the notif-leak mitigation —
  all documented in **[BUGS.md](BUGS.md)**.

---

## Install (Arch / CachyOS)

```bash
git clone https://github.com/siraxuth/myshell-dots.git
cd myshell-dots
./install.sh
```

The installer:
1. installs repo packages (`packages.txt`) + AUR packages (`caelestia-shell-git`,
   `caelestia-cli-git`, `mpvpaper`) — bootstrapping `yay` if no AUR helper is present;
2. backs up any existing config to `<path>.bak.<timestamp>` and copies this config in;
3. recreates the Caelestia symlinks (`~/.config/{btop,fish,hypr,foot,…}` →
   `~/.local/share/caelestia/*`);
4. creates `~/Videos/Wallpapers/` for the live-wallpaper picker.

Config-only (skip packages): `./install.sh --no-pkg`.

After install, log into the **Hyprland (uwsm)** session. If the shell isn't up:
`qs -c caelestia kill; caelestia shell -d`.

---

## What lives where

```
home/.config/quickshell/caelestia/   ← the Quickshell shell (all the customization)
home/.config/caelestia/              ← shell.json (settings) + launcher-prefs.json
home/.local/share/caelestia/         ← hypr, fish (incl. `wallive`), foot, btop, … (data dir)
packages.txt                         ← pacman + AUR package list
install.sh                           ← installer (Arch/CachyOS)
BUGS.md                              ← every known bug + the exact fix command
```

Key custom files:
- `…/quickshell/caelestia/modules/livewallpaper/{Wrapper,Content}.qml` + `services/LiveWallpaper.qml` — the picker.
- `…/quickshell/caelestia/services/LauncherPrefs.qml` — launcher position + search position prefs.
- `…/quickshell/caelestia/modules/launcher/Wrapper.qml` — position/animation logic.
- `…/local/share/caelestia/fish/functions/wallive.fish` — the mpvpaper video-wallpaper engine.
- `…/local/share/caelestia/hypr/hyprland/keybinds.conf` — keycode-based, Thai-safe binds.

---

## Default keybinds (the custom ones)

| Keys | Action |
|------|--------|
| `Super` (tap) | App launcher |
| `Super+Shift+W` | Live wallpaper picker (`code:25`, layout-independent) |
| `Ctrl+Super+Alt+R` | Kill + restart the shell (needed after edits — no hot-reload) |
| `Ctrl+Super+Shift+R` | Kill the shell |
| `Super+Space` | Toggle keyboard layout (us ↔ th) |

In the live-wallpaper picker: `← →` select+preview · `Enter` apply · `Esc` cancel · click a tile to apply · click outside to close.

---

## Migrating to CachyOS

CachyOS is Arch-based — `./install.sh` works as-is (pacman + AUR). Nothing else to do.

## Migrating to NixOS

The config files are portable; package management is not. On NixOS:
1. Run `./install.sh --no-pkg` to place the config trees and symlinks (or manage them via
   home-manager pointing at this repo's `home/` tree).
2. Declare the equivalents of `packages.txt` in `configuration.nix` /
   `home.packages` — notably: `hyprland`, `quickshell`, `mpvpaper`, `ffmpeg`, `fish`, `foot`,
   `fastfetch`, `btop`, `starship`, `fuzzel`, `cava`, `grim`, `brightnessctl`, `ddcutil`,
   `libqalculate`, `cliphist`, and the Material Symbols font.
3. `caelestia-shell` / `caelestia-cli` aren't in nixpkgs — build them from their repos or run
   Quickshell against this `~/.config/quickshell/caelestia` directly (the shell is just QML).
4. Keyboard/keycode binds and the `wallive` fish function are distro-independent.

---

## Maintenance

- After editing any QML: restart with `Ctrl+Super+Alt+R` (Quickshell 0.3.0 has no hot-reload).
- If the shell misbehaves, **[BUGS.md](BUGS.md)** has the symptom → fix for every issue hit so far.
- `wallive -s` / `wallive -ns` enable/disable live-wallpaper autostart on login.
