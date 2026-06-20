#!/usr/bin/env python3
"""lyrics-tty — fullscreen terminal karaoke for the currently playing song.

Reads the song + position from playerctl (MPRIS) and the matching .lrc that caelestia
already downloaded into the lyrics dir, then shows the current line big and centred,
synced to playback, with the previous/next lines dimmed. Thai-safe (Latin-only lines get
a big figlet/toilet block font if available; Thai/mixed lines render as large centred
text — figlet has no Thai glyphs). Ctrl-C / q to quit.
"""
import os, sys, re, json, glob, time, shutil, subprocess, signal, select, termios, tty
import urllib.request, urllib.parse

HOME = os.path.expanduser("~")
FIG = shutil.which("toilet") or shutil.which("figlet")
RESET = "\x1b[0m"
BLUE = "\x1b[1;38;5;39m"   # steady blue for the current line
DIM = "\x1b[2;37m"
SHOW_NEXT = any(a in ("--next", "-n") for a in sys.argv[1:])  # default: no next line


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


def parse_lrc_text(s):
    out = []
    for ln in s.splitlines():
        stamps = re.findall(r"\[(\d+):(\d+)(?:[.:](\d+))?\]", ln)
        text = re.sub(r"\[[^\]]*\]", "", ln).strip()
        for mm, ss, xx in stamps:
            t = int(mm) * 60 + int(ss) + (int((xx + "00")[:2]) / 100 if xx else 0)
            out.append((t, text))
    out.sort(key=lambda x: x[0])
    return out


def parse_lrc(path):
    try:
        return parse_lrc_text(open(path, encoding="utf-8", errors="replace").read())
    except Exception:
        return []


def _http(url):
    req = urllib.request.Request(url, headers={"Referer": "https://music.163.com/", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=6) as r:
        return r.read().decode("utf-8", "replace")


def fetch_netease(artist, title):
    """Same source the dashboard uses: NetEase search -> best artist match -> song lyric."""
    try:
        q = urllib.parse.quote(f"{title} {artist}".strip())
        res = json.loads(_http(f"https://music.163.com/api/search/get?s={q}&type=1&limit=5"))
        songs = (res.get("result") or {}).get("songs") or []
        if not songs:
            return None
        ia = str(artist or "").lower()
        best = next((s for s in songs if (lambda sa: sa and (sa in ia or ia in sa))(
            str((s.get("artists") or [{}])[0].get("name") or "").lower())), songs[0])
        lyr = json.loads(_http(f"https://music.163.com/api/song/lyric?id={best['id']}&lv=1&kv=1&tv=-1"))
        return (lyr.get("lrc") or {}).get("lyric")
    except Exception:
        return None


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

    d, song, lines, idx = lyrics_dir(), None, [], -1
    try:
        while True:
            if old and select.select([sys.stdin], [], [], 0)[0] and sys.stdin.read(1) in ("q", "Q"):
                cleanup()
            artist, title, status, pos = now()
            key = f"{artist}␟{title}"
            if key != song:
                song = key
                idx = -1
                lines = []
                lrc = find_lrc(d, artist, title)
                if lrc:
                    lines = parse_lrc(lrc)
                elif title:
                    txt = fetch_netease(artist, title)  # same source as the dashboard
                    if txt:
                        lines = parse_lrc_text(txt)
                        try:
                            os.makedirs(d, exist_ok=True)
                            open(os.path.join(d, f"{artist} - {title}.lrc"), "w", encoding="utf-8").write(txt)
                        except Exception:
                            pass
            cols, rows = shutil.get_terminal_size((80, 24))

            prev = nxt = status_line = ""
            if not title:
                block = ["(nothing playing)"]
            elif lines:
                ci = -1
                for i, (t, _) in enumerate(lines):
                    if t <= pos + 0.2:
                        ci = i
                    else:
                        break
                idx = ci
                cur = lines[ci][1] if ci >= 0 else "♪"
                block = big(cur or "♪", cols)
                prev = lines[ci - 1][1] if ci - 1 >= 0 else ""
                nxt = lines[ci + 1][1] if 0 <= ci + 1 < len(lines) else ""
            else:
                block = big(title, cols)
                status_line = f"{artist}   ·   (no synced lyrics)"

            body = []
            if prev:
                body.append((DIM, center(prev, cols)))
                body.append(("", ""))
            for r in block:
                body.append((BLUE, r))
            if status_line:
                body.append(("", ""))
                body.append((DIM, center(status_line, cols)))
            elif SHOW_NEXT and nxt:
                body.append(("", ""))
                body.append((DIM, center(nxt, cols)))

            top = max(0, (rows - len(body)) // 2)
            out = ["\x1b[H\x1b[2J", "\n" * top]
            for c, txt in body:
                out.append(f"{c}{txt}{RESET}\n" if c else f"{txt}\n")
            sys.stdout.write("".join(out))
            sys.stdout.flush()
            time.sleep(0.15)
    except Exception:
        cleanup()


if __name__ == "__main__":
    main()
