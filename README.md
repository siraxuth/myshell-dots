# myshell-dots

My personal **Caelestia + Hyprland** desktop configuration for Arch Linux and CachyOS. It includes the Quickshell UI, desktop settings, application configs, helper commands, and scripts I use every day.

The shell is based on [Caelestia](https://github.com/caelestia-dots/shell) and [caelestia-dots](https://github.com/caelestia-dots/caelestia), with local changes for laptop power use, taskbar placement, widgets, calendar events, and a more organized Settings window.

## Install

### One-command install

On a fresh Arch Linux or CachyOS install, run:

```bash
curl -fsSL https://raw.githubusercontent.com/siraxuth/myshell-dots/main/bootstrap.sh | bash
```

This clones the repository into `~/.local/share/myshell-dots`, installs the listed Arch and AUR packages, backs up conflicting configuration paths, and applies the dotfiles. It asks before installing the optional Acer laptop utility. Review [bootstrap.sh](bootstrap.sh), [install.sh](install.sh), and [packages.txt](packages.txt) before running the one-command installer.

### Manual install

```bash
git clone https://github.com/siraxuth/myshell-dots.git
cd myshell-dots
./install.sh
```

The installer can install packages and apply the included configuration. To skip package installation:

```bash
./install.sh --no-pkg
```

Existing files are backed up before the installer replaces or links them. Review `install.sh` and `packages.txt` before using this on another machine. The package step targets Arch-based distributions; on other distributions, install equivalent dependencies yourself and apply the `home/` files manually.

The installer also places the live-wallpaper thumbnail/transcode helper in `~/.local/bin/` and creates `~/Videos/Wallpapers/`. The config setup is safe to re-run; each replaced target gets a timestamped `.bak` backup.

## What’s included

### Caelestia shell

- **Settings / Control Center** with grouped navigation and dedicated pages for appearance, display, power, audio, Bluetooth, networking, notifications, widgets, and taskbar options.
- **Taskbar placement** on the left, top, or bottom. Workspace and status layouts follow the selected orientation, and the placement is saved across shell restarts.
- **Dashboard calendar** with event markers and a selected-day event list. The calendar popout can also create and manage events.
- **24-hour time** used throughout the shell, including the bar, dashboard, lock screen, forecasts, and activity timestamps.
- **Power controls** for battery-aware idle behavior and power profiles, plus a control for enabling or disabling the discrete GPU.
- **Storage & Disk Usage** with mounted-drive capacity, common-folder size breakdowns, app inspection, selected-file cleanup, and cache clearing. Scans run on demand at low I/O priority; destructive actions ask for confirmation.
- **Desktop widget canvas** with per-monitor positioning, sizing, layers, backgrounds, and styling for clock, calendar, music, weather, images, system metrics, battery, GitHub contribution activity, and visualizer widgets.
- **Music widget** with player selection, playback and shuffle controls, seek bar, audio spectrum, and album-art backgrounds.
- **Live wallpaper picker** backed by `mpvpaper`, with wallpaper selection and preview controls.
- **Launcher** with wallpaper browsing, color filtering, and configurable placement.
- **Workspace and status indicators** adapted for horizontal and vertical taskbars.

The shell source is in `home/.config/quickshell/caelestia/`.

### Hyprland and applications

The `home/` tree also contains Hyprland settings and scripts, plus configurations for Fish, Foot, Btop, Fastfetch, VS Code, Zed, Zen Browser, and other applications. `packages.txt` lists the packages used by the installer.

Useful Fish commands include:

| Command | Purpose |
| --- | --- |
| `appinstall` | Install the configured application set. |
| `wallive [path]` | Start, stop, or manage a video wallpaper. |
| `lyrics [--prev] [--next] [--edit]` | Show lyrics in a terminal. |
| `network [up\|down]` | Toggle configured VPN interfaces. |
| `cpp <file.cpp> [args…]` | Compile and run a C++ source file. |
| `cls` / `lutris` | Small shell helpers for clearing the terminal and starting Lutris. |
| `pacforce <pkg>` / `paruforce <pkg>` | Reinstall a package while allowing file conflicts to be overwritten. |

### Hyprland utilities

- `Print` opens the screenshot picker; `Super+Shift+S` opens a capture dashboard for screenshots and recordings. Screenshot OCR is configured in `hyprland/keybinds.conf`.
- `Super+V` opens the clipboard picker. The capture tools can open the screenshot editor for annotation.
- `monitor-watcher.fish`, `lid.fish`, and `workspace-mode.fish` handle monitor changes, laptop-lid behavior, and shared or per-monitor workspaces.
- `toggle-keyboard-waydroid.fish` switches the keyboard layout for the Waydroid workflow.

Scripts are stored in `home/.local/share/caelestia/hypr/scripts/` and copied into `~/.config/hypr/scripts/` by the installer.


See `BUGS.md` for machine-specific notes and fixes, including hybrid graphics, monitor setup, laptop lid behavior, and Thai keyboard layouts.

## Updating

Pull the latest repository changes, review them, then rerun the installer to apply the updated configuration:

```bash
git pull --ff-only
./install.sh --no-pkg
```

## Configuration locations

- `home/.config/quickshell/caelestia/` — Caelestia QML shell and settings UI.
- `home/.config/caelestia/` — Caelestia configuration and monitor profiles.
- `home/.local/share/caelestia/` — desktop, Fish, and application configuration files.
- `BUGS.md` — troubleshooting and machine-specific setup notes.

## Credits

- [Caelestia shell](https://github.com/caelestia-dots/shell)
- [Caelestia dotfiles](https://github.com/caelestia-dots/caelestia)
- [Quickshell](https://quickshell.org/)
- [Hyprland](https://hypr.land/)
