# myshell-dots

My customized **Caelestia** desktop — Hyprland + Quickshell — packaged so a fresh machine
(or a move to CachyOS / NixOS) comes back up with the *exact same* config and no surprises.

Built on top of [caelestia-dots](https://github.com/caelestia-dots). Everything below the
"What's added on top of Caelestia" line is **extra** — vanilla Caelestia does not ship it.
The guiding idea: anything you used to hand-edit in a JSON or conf file should have a GUI in
the **Control Center**, and anything you used to do with a long command should have a short
fish command.

---

## Install (Arch / CachyOS)

```bash
git clone https://github.com/siraxuth/myshell-dots.git
cd myshell-dots
./install.sh
```

The installer:
1. installs repo packages (`packages.txt`) + AUR packages (`caelestia-shell-git`,
   `caelestia-cli-git`, `mpvpaper`, `visual-studio-code-bin`, `zen-browser-bin`, …),
   bootstrapping `yay` if no AUR helper is present;
2. installs bundled fonts (e.g. `SOV_HuaHlim` for the Thai lyrics renderer) + `fc-cache`;
3. backs up any existing config to `<path>.bak.<timestamp>` and copies/symlinks this config in;
4. creates `~/Videos/Wallpapers/` for the live-wallpaper picker.

Flags:

| Command | What it does |
|---------|--------------|
| `./install.sh` | packages + configs + symlinks |
| `./install.sh --no-pkg` | configs + symlinks only (skip package install) |

Apps can also be (re)installed any time with the **`appinstall`** fish command (see below) —
handy after a fresh OS or on a second machine.

> **Other distros (NixOS, etc.):** the configs are portable; only the package step is
> Arch-specific. Skip it with `--no-pkg`, install the equivalents from your package manager,
> then symlink the `home/.config` / `home/.local` trees yourself. See **[BUGS.md](BUGS.md)**
> for the handful of system tweaks (hybrid GPU, boot race, Thai keymap, notif-leak watchdog).

---

## What's added on top of Caelestia

### Launcher
- **Position** — top / center / bottom, switchable in *Control Center → Launcher Settings*.
- **Search bar** — top or bottom, independently switchable.
- **Center launcher** — pops/expands from the screen centre with its own animation.

### Live wallpaper
- **Picker** — `Super+Shift+W` opens a dashboard-style drawer to choose a video from
  `~/Videos/Wallpapers/`. Arrow keys preview live, Enter applies, Esc closes (keeps current).
  Mutually exclusive with the launcher.
- **`wallive`** command (mpvpaper) drives it; the shell never decodes video itself. Runs on
  the `background` layer so the visualiser + desktop widgets stay **above** the video.

### Desktop widgets (all new)
Widgets drawn on the wallpaper (visible on the empty desktop), fully managed from a GUI:
- **Types:** Arch logo (centre-piece — pulsing glow, breathing, + a circular **audio-reactive
  ring** from the cava spectrum), Clock (big time + date), Media (cover art + title/artist +
  prev/play/next), Weather (icon/temp/desc/city), System (CPU / RAM / temp).
- **Manage them in *Control Center → Desktop Widgets*:** add, delete, pick type, set position
  on a **3×3 grid**, scale, **reorder** (▲▼), and toggle each widget's **background**
  (translucent card vs fully transparent) — no JSON editing.
- **Auto-stacking:** widgets that share a position stack in a column instead of overlapping,
  so e.g. a clock and weather in the same corner flow neatly under each other.
- Stored in `~/.config/caelestia/widgets.json` (own file — survives shell saves reliably).

### Per-monitor workspaces
- Each monitor starts at workspace 1 **independently**.
- `Super+1…9` switches the workspace on the monitor your **cursor/focus** is on (doesn't jump
  to the main monitor).
- Taskbar shows the real workspace **numbers** per monitor (no cross-monitor mixing).
- Toggle separate / shared in *Control Center → Display*.

### Control Center additions
- **Display** pane — arrange monitors as **draggable rectangles** scaled to real size (with
  snapping), set **resolution + refresh rate + scale** per monitor (every supported mode),
  and toggle workspace separate/shared.
- **Power** pane — power profile + **independent AC / battery** screen-idle timeouts
  (Never / 1 / 2 / 5 / 10 / 15 / 30 m). Caelestia's idle monitor is the sole authority
  (hypridle disabled) so the two don't fight.
- **Desktop Widgets** pane — see above.
- **NavRail** is now scrollable/centred so all the icons are reachable.

### Terminal lyrics (`lyrics`)
A tty karaoke tool — same lyric source as the dashboard (NetEase), big and centred:
- **Latin** lines render as thick **block text** (toilet `bigmono12`, tty-clock style),
  auto-fit to the terminal (shrinks the font / wraps long lines instead of overflowing).
- **Thai / non-Latin** renders large via a TTF (`SOV_HuaHlim`) → **transparent sixel**
  (custom encoder — no black box), wraps long lines, auto-fit. Needs a sixel terminal (foot).
- Steady **blue**; shows only the current line by default (`--prev` / `--next` add neighbours).
- **Filters out** NetEase Chinese credit/translation lines automatically.
- **`lyrics --edit`** opens (or creates) `~/Music/lyrics/<Title>.lrc` to add your own lyrics;
  a local `.lrc` overrides the online fetch.

---

## Commands (fish)

| Command | What it does |
|---------|--------------|
| `appinstall [--no-aur] [--damx]` | Install all myshell apps (pacman + AUR). `--no-aur` = repo only; `--damx` = also install DAMX (Acer fan/perf). `appinstall --help` lists the apps. |
| `wallive [path]` | Play a video wallpaper (last/default if no path). `wallive stop`, `wallive -s` / `-ns` (autostart on/off), `wallive -h`. |
| `lyrics [--prev] [--next] [--edit]` | Terminal lyrics for the playing song (run in foot). |
| `cpp <file.cpp> [args…]` | Compile a C++ file to `./out` and run it. |
| `network [up\|down]` | Toggle VPN interfaces (wg0, tailscale0) — e.g. for FlashPrint LAN scan. |
| `pacforce <pkg>` | `pacman -S --overwrite '*'` (resolve file conflicts). |
| `paruforce <pkg>` | AUR install with `--overwrite '*'`. |
| `zed [args]` | Alias for `zeditor`. |

### Helper scripts (`~/.local/share/caelestia/hypr/scripts/`)
Wired into Hyprland binds/execs — listed so you know what each does:

| Script | Purpose |
|--------|---------|
| `wsaction.fish` | Per-monitor workspace switching/movement (focused-monitor aware). |
| `workspace-mode.fish [separate\|shared]` | Switch per-monitor vs shared workspaces. |
| `screenshot-menu.sh` / `screenshot-ocr.sh` | Screenshot picker → clipboard (fuzzel menu) / OCR to clipboard. |
| `monitor-watcher.fish` | Apply layout on monitor connect, reset eDP on disconnect. |
| `lid.fish` | Laptop lid: blank eDP if external present, else suspend. |
| `configs.fish` | Config reload helper. |
| `lyrics-tty.py` | Backend for the `lyrics` command. |

---

## How customizable / what's easier than vanilla

Most things that used to mean editing a file by hand now have a GUI:

| Want to change… | Vanilla Caelestia | Here |
|-----------------|-------------------|------|
| Launcher position / search position | edit config | *Control Center → Launcher Settings* |
| Monitor arrangement / resolution / Hz | `hyprland.conf` by hand | *Control Center → Display* (drag + dropdowns) |
| Screen-off timing (AC vs battery) | hypridle config | *Control Center → Power* |
| Desktop widgets | n/a (didn't exist) | *Control Center → Desktop Widgets* (add/move/scale/bg/reorder) |
| Live wallpaper | n/a | `Super+Shift+W` picker / `wallive` |
| Per-monitor workspaces | manual rules | *Control Center → Display* toggle |
| Installing the app set | manual | `appinstall` / `./install.sh` |

Still file-editable for power users:
- `~/.config/caelestia/shell.json` — main shell config (launcher, services, weather location…).
- `~/.config/caelestia/widgets.json` — desktop widgets list.
- `~/.config/caelestia/*-prefs.json` — launcher / power / workspace prefs.
- `~/.config/quickshell/caelestia/` — the QML shell itself (every widget/pane is editable QML).

---

## Bug fixes & system tweaks

All the sharp edges (hybrid-GPU rendering, boot race, **Thai-layout-safe keybinds**,
NetEase lyric fetch, the qs memory-leak watchdog, sixel transparency, the JSON round-trip
gotcha behind `widgets.json`, …) are documented with exact commands in **[BUGS.md](BUGS.md)**
so a rebuild is reproducible.
