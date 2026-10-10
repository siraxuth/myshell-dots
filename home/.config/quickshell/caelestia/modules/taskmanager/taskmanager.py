#!/usr/bin/env python3
"""Process and startup data provider for the Caelestia Task Manager."""

from __future__ import annotations

import configparser
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
UID = os.getuid()
HZ = os.sysconf("SC_CLK_TCK")
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")
CPU_COUNT = os.cpu_count() or 1
HELPER_PID = os.getpid()
PROTECTED_NAMES = {
    "systemd", "init", "(sd-pam)", "hyprland", "quickshell", "Xwayland", "Xorg",
    "dbus-broker", "dbus-daemon", "pipewire", "pipewire-pulse", "wireplumber",
    "xdg-desktop-por", "xdg-document-po", "xdg-permission-", "polkit-gnome-au",
    "sddm", "sddm-helper", "greetd", "login", "agetty",
}
HYPR_FILES = [
    HOME / ".config/hypr/hyprland/execs.conf",
    HOME / ".config/caelestia/hypr-user.conf",
]
HYPR_VARIABLE_FILES = [
    HOME / ".config/hypr/variables.conf",
    HOME / ".config/caelestia/hypr-vars.conf",
]
DISABLED_PREFIX = "# Disabled in Caelestia Task Manager: "


def emit(data: object) -> None:
    print(json.dumps(data, ensure_ascii=False), flush=True)


def read_proc(pid: int) -> dict | None:
    base = Path("/proc") / str(pid)
    try:
        raw = (base / "stat").read_text()
        close = raw.rfind(")")
        if close < 0:
            return None
        name = raw[raw.find("(") + 1:close]
        fields = raw[close + 2:].split()  # starts at field 3 (state)
        status = (base / "status").read_text()
        uid_match = re.search(r"^Uid:\s+(\d+)", status, re.M)
        cmdline = (base / "cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace").strip()
        return {
            "pid": pid,
            "name": name,
            "cmd": cmdline or name,
            "state": fields[0],
            "ppid": int(fields[1]),
            "ticks": int(fields[11]) + int(fields[12]),
            "startTicks": int(fields[19]),
            "rss": max(0, int(fields[21])) * PAGE_SIZE,
            "uid": int(uid_match.group(1)) if uid_match else -1,
        }
    except (OSError, ValueError, IndexError):
        return None


def cpu_times() -> tuple[int, int]:
    fields = Path("/proc/stat").read_text().splitlines()[0].split()[1:]
    values = [int(value) for value in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    return sum(values), idle


def memory_snapshot() -> dict:
    values = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key, _, rest = line.partition(":")
        parts = rest.split()
        if parts:
            values[key] = int(parts[0]) * 1024
    total = values.get("MemTotal", 0)
    swap_total = values.get("SwapTotal", 0)
    return {
        "memTotal": total,
        "memUsed": max(0, total - values.get("MemAvailable", total)),
        "memCached": values.get("Cached", 0) + values.get("Buffers", 0),
        "swapTotal": swap_total,
        "swapUsed": max(0, swap_total - values.get("SwapFree", swap_total)),
    }


def process_allowed(proc: dict) -> bool:
    return proc["uid"] == UID and proc["pid"] != HELPER_PID and proc["name"] not in PROTECTED_NAMES


def monitor(interval: float) -> None:
    previous = {}
    total_before, idle_before = cpu_times()
    time_before = time.monotonic()
    first = True
    while True:
        current = {}
        for name in os.listdir("/proc"):
            if name.isdigit():
                proc = read_proc(int(name))
                if proc and proc["state"] != "Z" and proc["rss"] > 0:
                    current[proc["pid"]] = proc

        total_after, idle_after = cpu_times()
        time_after = time.monotonic()
        elapsed = max(time_after - time_before, 0.001)
        total_delta = total_after - total_before
        system_cpu = 0 if first or total_delta <= 0 else 100 * (1 - (idle_after - idle_before) / total_delta)
        procs = []
        for pid, proc in current.items():
            old_ticks = previous.get(pid, {}).get("ticks")
            cpu = 0.0
            if old_ticks is not None and pid in previous and previous[pid]["startTicks"] == proc["startTicks"] and not first:
                cpu = max(0, (proc["ticks"] - old_ticks) / HZ / elapsed * 100 / CPU_COUNT)
            if pid == HELPER_PID:
                continue
            procs.append({
                "pid": pid,
                "name": proc["name"],
                "cmd": proc["cmd"][:500],
                "rss": proc["rss"],
                "cpu": round(cpu, 1),
                "uid": proc["uid"],
                "startTicks": proc["startTicks"],
                "state": proc["state"],
                "killAllowed": process_allowed(proc),
            })
        snapshot = memory_snapshot()
        snapshot.update({"cpu": round(max(0, system_cpu), 1), "cores": CPU_COUNT, "procs": procs})
        emit(snapshot)
        previous = current
        total_before, idle_before, time_before = total_after, idle_after, time_after
        first = False
        time.sleep(max(0.5, min(interval, 5)))


def executable_for(command: str) -> str:
    command = expand_hypr_variables(command)
    try:
        parts = shlex.split(command)
    except ValueError:
        return ""
    while parts and (parts[0].startswith("#") or parts[0].endswith("=")):
        parts.pop(0)
    if parts and Path(parts[0]).name == "env":
        parts.pop(0)
        while parts and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", parts[0]):
            parts.pop(0)
    if not parts:
        return ""
    executable = Path(parts[0]).name
    return executable.replace("%", "")


def expand_hypr_variables(command: str) -> str:
    variables = {}
    for path in HYPR_VARIABLE_FILES:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        for line in lines:
            match = re.match(r"^\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$", line)
            if match:
                variables[match.group(1)] = match.group(2).strip().strip("\"")
    expanded = command
    for _ in range(8):
        next_value = re.sub(r"\$([A-Za-z_][A-Za-z0-9_]*)", lambda match: variables.get(match.group(1), match.group(0)), expanded)
        if next_value == expanded:
            break
        expanded = next_value
    return expanded


def candidate_pids(command: str) -> list[int]:
    executable = executable_for(command)
    if not executable:
        return []
    matches = []
    for proc_dir in Path("/proc").iterdir():
        if not proc_dir.name.isdigit():
            continue
        proc = read_proc(int(proc_dir.name))
        if not proc or proc["uid"] != UID or proc["state"] == "Z":
            continue
        try:
            argv0 = (proc_dir / "cmdline").read_bytes().split(b"\0", 1)[0].decode("utf-8", "replace")
        except OSError:
            continue
        if Path(argv0).name == executable and proc["name"] not in PROTECTED_NAMES:
            matches.append(proc["pid"])
    return matches


def desktop_dirs() -> list[Path]:
    xdg = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    return [xdg / "autostart", Path("/etc/xdg/autostart"),
            *(Path(item) / "autostart" for item in data_dirs if item)]


def parse_desktop(path: Path) -> dict:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    group = parser["Desktop Entry"] if parser.has_section("Desktop Entry") else {}
    return {
        "name": group.get("Name", path.stem),
        "exec": group.get("Exec", ""),
        "hidden": group.get("Hidden", "false").lower() == "true",
        "type": group.get("Type", "Application"),
        "noDisplay": group.get("NoDisplay", "false").lower() == "true",
    }


def desktop_entries() -> list[dict]:
    by_name = {}
    ordered = []
    dirs = desktop_dirs()
    user_dir = dirs[0]
    for directory in reversed(dirs):
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.desktop")):
            info = parse_desktop(path)
            if info["type"] != "Application":
                continue
            entry = {
                "id": f"xdg:{path.name}", "name": info["name"], "exec": info["exec"],
                "source": "XDG Autostart", "kind": "desktop", "path": str(path),
                "enabled": not info["hidden"], "systemEntry": path.parent != user_dir,
            }
            if path.name not in by_name:
                ordered.append(path.name)
            by_name[path.name] = entry
    return [by_name[name] for name in ordered if name in by_name]


def parse_hypr_entries() -> list[dict]:
    entries = []
    for path in HYPR_FILES:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        counts = {}
        for index, line in enumerate(lines):
            stripped = line.strip()
            enabled = True
            candidate = stripped
            if stripped.startswith(DISABLED_PREFIX):
                enabled = False
                candidate = stripped[len(DISABLED_PREFIX):]
            if candidate.startswith("#"):
                continue
            match = re.match(r"^exec-once\s*=\s*(.*)$", candidate, re.I)
            if not match:
                continue
            command = match.group(1).strip()
            digest = hashlib.sha1(command.encode()).hexdigest()[:12]
            occurrence = counts.get(digest, 0)
            counts[digest] = occurrence + 1
            entries.append({
                "id": f"hypr:{path}:{digest}:{occurrence}", "name": executable_for(command) or command[:80],
                "exec": command, "source": "Hyprland exec-once", "kind": "hypr",
                "path": str(path), "line": index, "enabled": enabled,
            })
    return entries


def systemd_entries() -> list[dict]:
    result = subprocess.run(
        ["systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager"],
        capture_output=True, text=True, timeout=8,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not read user services")
    active_result = subprocess.run(
        ["systemctl", "--user", "list-units", "--type=service", "--all", "--no-legend", "--no-pager"],
        capture_output=True, text=True, timeout=8,
    )
    active_by_unit = {}
    for line in active_result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 4:
            active_by_unit[fields[0]] = fields[2]
    entries = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) < 2 or not fields[0].endswith(".service"):
            continue
        unit, state = fields[0], fields[1]
        manageable = state not in {"static", "indirect", "alias", "generated", "transient", "masked"}
        entries.append({
            "id": f"systemd:{unit}", "name": unit.removesuffix(".service"), "exec": unit,
            "source": "systemd user", "kind": "systemd", "enabled": state.startswith("enabled"),
            "running": active_by_unit.get(unit) == "active", "manageable": manageable,
            "reason": "Service is managed by another unit" if state in {"static", "indirect", "alias", "generated", "transient"} else "Service is masked" if state == "masked" else "",
        })
    return entries


def startup_list() -> None:
    entries = []
    warnings = []
    for source, load in (("XDG Autostart", desktop_entries), ("Hyprland", parse_hypr_entries), ("systemd user", systemd_entries)):
        try:
            entries.extend(load())
        except Exception as error:
            warnings.append(f"{source}: {error}")
    for entry in entries:
        if entry["kind"] in {"desktop", "hypr"}:
            pids = candidate_pids(entry["exec"])
            entry["running"] = len(pids) > 0
            entry["matchingPids"] = pids
            entry["liveMatchAmbiguous"] = len(pids) > 1
    emit({"ok": True, "entries": entries, "warnings": warnings})


def backup(path: Path) -> None:
    if not path.exists():
        return
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target = path.with_name(f"{path.name}.bak-taskmanager-{stamp}")
    suffix = 1
    while target.exists():
        target = path.with_name(f"{path.name}.bak-taskmanager-{stamp}-{suffix}")
        suffix += 1
    shutil.copy2(path, target)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    backup(path)
    temp = path.with_name(f".{path.name}.taskmanager-{os.getpid()}")
    temp.write_text(content, encoding="utf-8")
    temp.chmod(path.stat().st_mode & 0o777 if path.exists() else 0o644)
    os.replace(temp, path)


def update_desktop(entry_id: str, enabled: bool) -> tuple[str, str]:
    basename = entry_id.removeprefix("xdg:")
    entries = desktop_entries()
    entry = next((item for item in entries if item["id"] == entry_id), None)
    if not entry:
        raise RuntimeError("Startup entry no longer exists")
    user_dir = desktop_dirs()[0]
    override = user_dir / basename
    if enabled:
        if override.exists() and Path(entry["path"]) != override:
            backup(override)
            override.unlink()
        elif override.exists():
            write_hidden(override, False)
        launch_desktop(Path(entry["path"]) if Path(entry["path"]) != override else override)
        return "enabled", "Startup enabled and app launch requested"
    if Path(entry["path"]) == override:
        write_hidden(override, True)
    else:
        override.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(override, "[Desktop Entry]\nType=Application\nHidden=true\n")
    stopped = stop_single_match(entry["exec"])
    return "disabled", "Startup disabled. " + stopped


def write_hidden(path: Path, hidden: bool) -> None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    if not parser.has_section("Desktop Entry"):
        parser.add_section("Desktop Entry")
    parser["Desktop Entry"]["Hidden"] = "true" if hidden else "false"
    from io import StringIO
    output = StringIO()
    parser.write(output, space_around_delimiters=False)
    atomic_write(path, output.getvalue())


def launch_desktop(path: Path) -> None:
    info = parse_desktop(path)
    try:
        parts = shlex.split(info["exec"])
    except ValueError as error:
        raise RuntimeError(f"Invalid desktop command: {error}")
    parts = [re.sub(r"%[fFuUdDnNickvm]", "", part) for part in parts]
    parts = [part for part in parts if part]
    if not parts:
        raise RuntimeError("Desktop entry has no launch command")
    env = os.environ.copy()
    if Path(parts[0]).name == "env":
        parts.pop(0)
        while parts and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", parts[0]):
            key, value = parts.pop(0).split("=", 1)
            env[key] = value
    if not parts:
        raise RuntimeError("Desktop entry has no executable")
    subprocess.Popen(parts, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)


def stop_single_match(command: str) -> str:
    pids = candidate_pids(command)
    if len(pids) == 1:
        proc = read_proc(pids[0])
        if proc and process_allowed(proc):
            os.kill(pids[0], signal.SIGTERM)
            return "Requested app to close"
    if len(pids) > 1:
        return "Startup changed; multiple matching processes remain. Choose a process in Processes to close it safely."
    return "Startup changed; no matching running process was found."


def update_hypr(entry_id: str, enabled: bool) -> tuple[str, str]:
    parts = entry_id.split(":")
    if len(parts) < 4:
        raise RuntimeError("Invalid Hyprland startup entry")
    path = Path(":".join(parts[1:-2]))
    digest, occurrence = parts[-2], int(parts[-1])
    if path not in HYPR_FILES:
        raise RuntimeError("Startup file is outside the supported Hyprland configuration")
    lines = path.read_text(encoding="utf-8").splitlines()
    seen = 0
    target = -1
    command = ""
    for index, line in enumerate(lines):
        candidate = line.strip()
        if candidate.startswith(DISABLED_PREFIX):
            candidate = candidate[len(DISABLED_PREFIX):]
        if candidate.startswith("#"):
            continue
        match = re.match(r"^exec-once\s*=\s*(.*)$", candidate, re.I)
        if not match:
            continue
        candidate_command = match.group(1).strip()
        if hashlib.sha1(candidate_command.encode()).hexdigest()[:12] != digest:
            continue
        if seen == occurrence:
            target, command = index, candidate_command
            break
        seen += 1
    if target < 0:
        raise RuntimeError("Startup command changed; refresh the list and try again")
    if enabled:
        if lines[target].strip().startswith(DISABLED_PREFIX):
            leading = lines[target][:len(lines[target]) - len(lines[target].lstrip())]
            lines[target] = leading + lines[target].lstrip()[len(DISABLED_PREFIX):]
        message = "Startup enabled"
    else:
        leading = lines[target][:len(lines[target]) - len(lines[target].lstrip())]
        original = lines[target].lstrip()
        if not original.startswith(DISABLED_PREFIX):
            lines[target] = leading + DISABLED_PREFIX + original
        message = stop_single_match(command)
    atomic_write(path, "\n".join(lines) + "\n")
    result = subprocess.run(["hyprctl", "reload"], capture_output=True, text=True, timeout=8)
    if result.returncode:
        raise RuntimeError(message + "; configuration saved, but Hyprland reload failed: " + (result.stderr.strip() or result.stdout.strip()))
    if enabled:
        expanded = expand_hypr_variables(command)
        result = subprocess.run(["hyprctl", "dispatch", "exec", expanded], capture_output=True, text=True, timeout=8)
        if result.returncode:
            raise RuntimeError("Startup enabled, but launch failed: " + (result.stderr.strip() or result.stdout.strip()))
        message += " and launch requested"
    return "enabled" if enabled else "disabled", message


def update_systemd(entry_id: str, enabled: bool) -> tuple[str, str]:
    unit = entry_id.removeprefix("systemd:")
    if not re.fullmatch(r"[A-Za-z0-9_.@:-]+\.service", unit):
        raise RuntimeError("Invalid user service name")
    operation = "enable" if enabled else "disable"
    entry = next((item for item in systemd_entries() if item["id"] == entry_id), None)
    if not entry:
        raise RuntimeError("Service no longer exists")
    if not entry["manageable"]:
        raise RuntimeError(entry["reason"] or "This service cannot be enabled or disabled")
    result = subprocess.run(["systemctl", "--user", operation, "--now", unit],
                            capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"systemctl {operation} failed")
    return operation, f"{unit} {operation}d and {'started' if enabled else 'stopped'}"


def set_startup(entry_id: str, enabled: bool) -> None:
    if entry_id.startswith("xdg:"):
        status, message = update_desktop(entry_id, enabled)
    elif entry_id.startswith("hypr:"):
        status, message = update_hypr(entry_id, enabled)
    elif entry_id.startswith("systemd:"):
        status, message = update_systemd(entry_id, enabled)
    else:
        raise RuntimeError("Unsupported startup source")
    emit({"ok": True, "id": entry_id, "enabled": enabled, "status": status, "message": message})


def end_process(pid: int, start_ticks: int, force: bool) -> None:
    proc = read_proc(pid)
    if not proc or proc["startTicks"] != start_ticks:
        raise RuntimeError("That process has already exited or changed. Refreshing the list.")
    if not process_allowed(proc):
        raise RuntimeError("This process is protected or belongs to another user")
    os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
    emit({"ok": True, "pid": pid, "forced": force, "message": "Force kill sent" if force else "Close request sent"})


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if action == "monitor":
            monitor(float(sys.argv[2]) if len(sys.argv) > 2 else 1.0)
        elif action == "startup":
            startup_list()
        elif action == "set-startup":
            set_startup(sys.argv[2], sys.argv[3] == "true")
        elif action == "end":
            end_process(int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] == "true")
        else:
            raise RuntimeError("Unknown task manager action")
    except Exception as error:  # Return actionable UI errors; never leave the panel blank.
        emit({"ok": False, "message": str(error)})


if __name__ == "__main__":
    main()
