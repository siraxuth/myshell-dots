# Caelestia Shell

<p align="center">
  <strong>A personal Quickshell desktop built for Hyprland.</strong><br>
  Fast controls, expressive widgets, and a desktop that feels like one system.
</p>

<p align="center">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-powered-7C3AED?style=for-the-badge">
  <img alt="Qt Quick" src="https://img.shields.io/badge/Qt_Quick-QML-41CD52?style=for-the-badge&logo=qt">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-desktop-00A4FF?style=for-the-badge">
</p>

Caelestia is a modular desktop shell configuration written in QML. It brings the bar, dashboard, launcher, settings, wallpaper controls, and desktop widgets together under one Material-inspired visual system.

## Highlights

- **A complete desktop surface:** panel, workspaces, system indicators, popouts, launcher, dashboard, sidebar, session menu, OSD, and lock screen.
- **Control Center:** adjust appearance, displays, audio, networking, Bluetooth, power, notifications, taskbar, and dashboard settings in one place.
- **Widget canvas:** place and resize widgets per monitor, tune their layout and styling, and preview them at real screen scale.
- **Built-in widgets:** clock, calendar, music, weather, image, system metrics, battery, GitHub activity, and visualizer.
- **Music controls:** select a media player, control playback and shuffle, seek through tracks, show album art, and display an audio spectrum.
- **Dashboard calendar:** review and manage events directly from the dashboard.
- **Wallpaper studio:** browse static and live wallpapers, preview them, and switch modes from the shell.
- **System-aware behavior:** monitor resources and power state, and adapt controls to the hardware and connected displays.
- **Consistent interaction:** shared colors, typography, spacing, shapes, and motion keep the shell cohesive.

## Requirements

This configuration is intended to run with:

- Linux with **Hyprland**
- **Quickshell** and the Caelestia services/modules used by this shell
- **M3Shapes** QML module (`qt6-m3shapes-git` on Arch) for expressive profile shapes and masking
- A working user session with the desktop services you want to control, such as NetworkManager, PipeWire/WirePlumber, Bluetooth, and UPower

Some controls depend on the corresponding system service and permissions being available. The shell does not replace those services.

## Install

Back up an existing configuration before replacing it. Place this directory at `~/.config/quickshell/caelestia`, then launch it with:

```sh
caelestia shell
```

For development or troubleshooting, run:

```sh
caelestia shell -d
```

The shell loads from `shell.qml`. QML modules are organized by desktop surface under `modules/`, reusable visual components under `components/`, configuration adapters under `config/`, and shared services under `services/`.

## Widget canvas

Open the widget editor from the Control Center or use the configured `widgetEditor` shortcut. The canvas supports per-monitor layouts, placement, resizing, variants, and widget-specific settings. Layouts are persisted locally by monitor; existing `widgets.json` layouts are migrated when they are first loaded.

Select a widget to edit its available options. Music widgets can follow the active player or target a specific player, use the album cover as a background, and customize text/accent colors and playback features. Image widgets accept local file paths, including `~/Pictures/...` paths.

## Project map

| Path | Purpose |
| --- | --- |
| `shell.qml` | Shell entry point and top-level modules |
| `modules/bar/` | Panel, workspaces, and popouts |
| `modules/dashboard/` | Dashboard and its calendar/media views |
| `modules/settings/` | Control Center panes and settings UI |
| `modules/widgets/` | Canvas editor, layout runtime, and widget faces |
| `modules/background/` | Desktop background, wallpaper, and standalone widgets |
| `modules/livewallpaper/` | Live wallpaper picker and controls |
| `services/` | Shared state, persistence, and system integrations |
| `components/` | Reusable controls and visual primitives |
| `config/` | Caelestia configuration adapters |

## Development notes

- Keep UI changes aligned with the existing Caelestia components and Material-derived tokens.
- Use `qsTr()` for user-facing strings so they can be translated.
- Persistent user settings belong in the appropriate service or config adapter, not in transient view state.
- Start the shell in debug mode to inspect QML load errors and runtime warnings.

## License

See [LICENSE](LICENSE).

## Desktop canvas

Control Center → Widgets uses the shared `PaneFrame`, including its inner border and rounding. “Arrange desktop · Full screen” opens a Wayland overlay covering the selected monitor at its native logical size. The editor and Control Center preview share `WidgetWorkspace`; geometry is stored in desktop coordinates.

- Select with a click; Ctrl+click selects more. Drag or use arrow keys (Shift moves 10 pixels).
- Ctrl+A selects all; Delete removes the selection; Ctrl+Z / Ctrl+Shift+Z undo and redo.
- F6 hides/shows editor tools; Escape returns from focus mode or closes the editor.
- Calm, Studio and Monitor offer a preview before replacing a monitor’s layout. Replacement can be undone.
- Layouts save automatically per monitor. The inspector exposes saving failures and a retry action.
- IPC: `qs ipc -c caelestia call widgetEditor open eDP-1` and `qs ipc -c caelestia call widgetEditor close`.

History holds 50 snapshots per monitor for the current shell session. The existing layout JSON format is retained.
