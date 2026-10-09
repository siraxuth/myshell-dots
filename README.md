# myshell-dots

My personal **Caelestia + Hyprland** desktop configuration for Arch Linux and CachyOS. It includes the Quickshell UI, desktop settings, application configs, helper commands, and scripts I use every day.

The shell is based on [Caelestia](https://github.com/caelestia-dots/shell) and [caelestia-dots](https://github.com/caelestia-dots/caelestia), with local changes for laptop power use, taskbar placement, widgets, calendar events, and a more organized Settings window.

## Install

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

## What’s included

### Caelestia shell

- **Settings / Control Center** with grouped navigation and dedicated pages for appearance, display, power, audio, Bluetooth, networking, notifications, widgets, and taskbar options.
- **Taskbar placement** on the left, top, or bottom. Workspace and status layouts follow the selected orientation, and the placement is saved across shell restarts.
- **Dashboard calendar** with event markers and a selected-day event list. The calendar popout can also create and manage events.
- **24-hour time** used throughout the shell, including the bar, dashboard, lock screen, forecasts, and activity timestamps.
- **Power controls** for battery-aware idle behavior and power profiles, plus a control for enabling or disabling the discrete GPU.
- **Storage & Disk Usage** with mounted-drive capacity, common-folder size breakdowns, app inspection, selected-file cleanup, and cache clearing. Scans run on demand at low I/O priority; destructive actions ask for confirmation.
- **Dashboard and desktop widgets** for media, weather, system information, and clock details.
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

Hyprland helper scripts, including `workspace-mode.fish`, live in `home/.local/share/caelestia/hypr/scripts/`.

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
