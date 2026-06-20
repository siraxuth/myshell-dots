# Known bugs & fixes — sharp reference

Every gotcha hit on this setup, with the exact command to fix it. Format: **symptom → cause → fix**.

---

## Shell / Quickshell

### qs eats RAM + CPU, climbs forever (RSS to GBs, 100% CPU)
**Cause:** `~/.local/state/caelestia/notifs.json` grows unbounded (no retention cap). Browser web-push spam (e.g. Instagram via Zen) piles up thousands of entries; the notifications module iterates them continuously. NOT a Qt/kernel/GPU leak.
**Fix:**
```bash
wc -c ~/.local/state/caelestia/notifs.json
echo "[]" > ~/.local/state/caelestia/notifs.json
qs -c caelestia kill; caelestia shell -d
```
Then stop the source (disable web push in the browser).

### Edited a QML config file, nothing changed
**Cause:** Quickshell 0.3.0 has **no hot-reload**.
**Fix:** restart the shell — `Ctrl+Super+Alt+R`, or:
```bash
qs -c caelestia kill; sleep 1; caelestia shell -d
```

### Never `pkill -f qs` / `pkill -f quickshell`
**Cause:** `pkill -f` matches your own shell command line too and kills the parent bash (exit 144); also leaves zombie daemons holding global shortcuts.
**Fix:** always use the instance-aware kill: `qs -c caelestia kill`.

### Bar/wallpaper missing right after boot ("Cannot connect to hyprland")
**Cause:** the user systemd unit `caelestia-shell.service` started before Hyprland exported `HYPRLAND_INSTANCE_SIGNATURE`; the daemon came up broken and the `exec-once` then skipped it.
**Fix:**
```bash
systemctl --user disable caelestia-shell.service
```
Startup is handled by `exec-once = caelestia shell -d` in hyprland.conf.

### Config edit didn't load — verify it parses first
```bash
timeout 4 qs -c caelestia 2>&1 | grep -iE 'error|not a type|unavailable'
# "Terminated" with no error lines = loads clean (the timeout just killed a healthy run)
```

---

## Hyprland / keybinds

### A keybind dies when the keyboard layout is Thai (us,th)
**Cause:** letter-based binds (e.g. `, L` / `, W`) don't match when the active layout is Thai.
**Fix:** bind by **keycode**, not letter. Examples in this config:
- Lock uses `code:46` (the `L` key), not `L`.
- Live-wallpaper picker uses `Super+Shift, code:25` (the `W` key), not `W`.
Find a keycode: `wev` (press the key) or evdev tables (W=25, L=46, Z=52, X=53).

### Lock screen types Thai → wrong password
**Cause:** layout not forced to English before locking.
**Fix:** the lock bind runs `hyprctl switchxkblayout all 0` first (see hypr keybinds.conf); keep that line.

### Session "stuck" — switch / mouse binds don't fire
**Cause:** `bindm`/switch binds only match the **root** submap; the session sat in submap `global`.
**Fix:** wrap such binds in `submap = reset`. Also `grp:win_space_toggle` breaks the Super-tap launcher — it's removed in favour of an explicit `switchxkblayout` bind on Super+Space.

### Cursor can't cross between the two stacked monitors
**Cause:** `eDP-1` placed with `auto-down`; Hyprland 0.55 recomputes adjacency wrong after a monitor enable/disable cycle.
**Fix:** pin explicit coords in `~/.config/hypr/monitors.conf` — `eDP-1` at `0x1080` (below `HDMI-A-2` at `0x0`). And make sure `source = $hypr/monitors.conf` is present in hyprland.conf (nwg-displays does not add it).

### NVIDIA/Intel dmabuf crash on hybrid GPU
**Fix:** force the Intel iGPU primary (already in `hypr-user.conf`):
```
env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card0
```

---

## Live wallpaper (Super+Shift+W)

### Picker shows but is an empty/zero-size frame, no tiles
**Cause:** a QML file missing `import Caelestia.Config` → `Tokens` undefined → every size collapses.
**Fix:** ensure `modules/livewallpaper/Content.qml` imports `Caelestia.Config`. (Already fixed here.)

### Video wallpaper vanishes / gets covered after a shell restart
**Cause:** mpvpaper on the default `background` layer sits under Caelestia's opaque static wallpaper, which is recreated on restart.
**Fix:** run mpvpaper on the `bottom` layer (above the static bg, below windows). `wallive` already does:
```
mpvpaper -fp -l bottom -o "no-audio --loop --hwdec=vaapi --vo=gpu-next" ALL <video>
```

### Caelestia's static wallpaper flashes between video switches
**Fix:** while a live wallpaper is active the shell sets `background.wallpaperEnabled = false` (the static bg becomes transparent and never shows). Picking **None/Stop** restores it.

### `wallive` not found from a script / exec-once
**Cause:** it's a fish *function*, not a binary.
**Fix:** call it via fish: `fish -c "wallive <path>"`. Autostart is wired as `exec-once = fish -c "wallive autostart"`.

### Duplicate mpvpaper processes
**Fix:** `pkill -x mpvpaper` then re-apply. `wallive` pkills before starting; a race can leave two.

---

## Python / tooling

### GUI/GTK python tools (e.g. `smile`, PyGObject) fail to import
**Cause:** `pyenv` (3.12) shadows the system python (3.14); PyGObject is built for the system one.
**Fix:** run those with `/usr/bin/python`, or set `pyenv local system` in that project dir.

---

## Boot speed (optional)
- `NetworkManager-wait-online.service` masked (~8.7s saved): `sudo systemctl mask NetworkManager-wait-online.service`
- `wg-quick@wg0.service` kept enabled by choice (VPN at boot, ~5s).

---

## Quick health check
```bash
# is the shell alive?
caelestia shell -d            # prints "An instance ... already running" if up
# what's listening on IPC?
qs -c caelestia ipc call drawers list
# live wallpaper state
cat ~/.config/wallive/path ; ps -ef | grep '[m]pvpaper'
```
