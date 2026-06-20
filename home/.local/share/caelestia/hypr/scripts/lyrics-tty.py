#!/usr/bin/env python3
"""lyrics-tty — fullscreen terminal karaoke for the currently playing song.

Reads the song + position from playerctl (MPRIS) and the matching .lrc that caelestia
already downloaded into the lyrics dir, then shows the current line big and centred,
synced to playback, with the previous/next lines dimmed. Thai-safe (Latin-only lines get
a big figlet/toilet block font if available; Thai/mixed lines render as large centred
text — figlet has no Thai glyphs). Ctrl-C / q to quit.
"""
import os, sys, re, json, glob, time, shutil, subprocess, signal, select, termios, tty

HOME = os.path.expanduser("~")
FIG = shutil.which("toilet") or shutil.which("figlet")
RESET = "\x1b[0m"


def lyrics_dir():
    d = f"{HOME}/Music/lyrics/"
    try:
        c = json.load(open(f"{HOME}/.config/caelestia/shell.json"))
        d = c.get("paths", {}).get("lyricsDir") or d
    except Exception:
        pass
    return os.path.expanduser(d.replace("$HOME", HOME))


def pctl(*a):
    try:
        return subprocess.run(["playerctl", *a], capture_output=True, text=True, timeout=1).stdout.strip()
    except Exception:
        return ""


def now():
    artist, title, status = pctl("metadata", "artist"), pctl("metadata", "title"), pctl("status")
    try:
        pos = float(pctl("position") or 0)
    except ValueError:
        pos = 0.0
    return artist, title, status, pos


def find_lrc(d, artist, title):
    if not title:
        return None
    for c in ([os.path.join(d, f"{artist} - {title}.lrc")] if artist else []) + [os.path.join(d, f"{title}.lrc")]:
        if os.path.isfile(c):
            return c
    for f in glob.glob(os.path.join(d, "**", "*.lrc"), recursive=True):
        b = os.path.basename(f).lower()
        if title.lower() in b and (not artist or artist.lower() in b):
            return f
    return None


def parse_lrc(path):
    out = []
    try:
        for ln in open(path, encoding="utf-8", errors="replace"):
            stamps = re.findall(r"\[(\d+):(\d+)(?:[.:](\d+))?\]", ln)
            text = re.sub(r"\[[^\]]*\]", "", ln).strip()
            for mm, ss, xx in stamps:
                t = int(mm) * 60 + int(ss) + (int((xx + "00")[:2]) / 100 if xx else 0)
                out.append((t, text))
    except Exception:
        return []
    out.sort(key=lambda x: x[0])
    return out


def width(s):
    try:
        from wcwidth import wcswidth
        w = wcswidth(s)
        return w if w >= 0 else len(s)
    except Exception:
        return len(s)


def center(s, cols):
    return " " * max(0, (cols - width(s)) // 2) + s


def big(line, cols):
    """Return a list of rows rendering `line` large."""
    if line and FIG and line.isascii():
        try:
            art = subprocess.run([FIG, line] if FIG.endswith("figlet") else [FIG, "-f", "future", line],
                                 capture_output=True, text=True, timeout=1).stdout.rstrip("\n").split("\n")
            return [center(r, cols) for r in art]
        except Exception:
            pass
    return [center(line, cols)]


def main():
    if not shutil.which("playerctl"):
        print("playerctl is not installed — run:  sudo pacman -S playerctl")
        return
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd) if sys.stdin.isatty() else None
    if old:
        tty.setcbreak(fd)
    sys.stdout.write("\x1b[?1049h\x1b[?25l")

    def cleanup(*_):
        sys.stdout.write("\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()
        if old:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    d, song, lines, idx, pulse = lyrics_dir(), None, [], -1, 0
    try:
        while True:
            if old and select.select([sys.stdin], [], [], 0)[0] and sys.stdin.read(1) in ("q", "Q"):
                cleanup()
            artist, title, status, pos = now()
            key = f"{artist}␟{title}"
            if key != song:
                song = key
                idx = -1
                lrc = find_lrc(d, artist, title)
                lines = parse_lrc(lrc) if lrc else []
            cols, rows = shutil.get_terminal_size((80, 24))

            if not title:
                block, sub = ["(nothing playing)"], "♪"
            elif lines:
                ci = -1
                for i, (t, _) in enumerate(lines):
                    if t <= pos + 0.2:
                        ci = i
                    else:
                        break
                if ci != idx:
                    idx, pulse = ci, 4
                cur = lines[ci][1] if ci >= 0 else "♪"
                block = big(cur or "♪", cols)
                prev = lines[ci - 1][1] if ci - 1 >= 0 else ""
                nxt = lines[ci + 1][1] if 0 <= ci + 1 < len(lines) else ""
                sub = (prev, nxt)
            else:
                block, sub = big(title, cols), f"{artist}   ·   (no synced lyrics)"

            body = []
            if isinstance(sub, tuple):
                body.append(("\x1b[2;37m", center(sub[0], cols)))
                body.append(("", ""))
            colour = "\x1b[1;38;5;213m" if pulse > 0 else "\x1b[1;38;5;111m"
            for r in block:
                body.append((colour, r))
            if isinstance(sub, tuple):
                body.append(("", ""))
                body.append(("\x1b[2;37m", center(sub[1], cols)))
            else:
                body.append(("", ""))
                body.append(("\x1b[2;37m", center(sub, cols)))

            top = max(0, (rows - len(body)) // 2)
            out = ["\x1b[H\x1b[2J", "\n" * top]
            for c, txt in body:
                out.append(f"{c}{txt}{RESET}\n" if c else f"{txt}\n")
            sys.stdout.write("".join(out))
            sys.stdout.flush()
            if pulse > 0:
                pulse -= 1
            time.sleep(0.15)
    except Exception:
        cleanup()


if __name__ == "__main__":
    main()
