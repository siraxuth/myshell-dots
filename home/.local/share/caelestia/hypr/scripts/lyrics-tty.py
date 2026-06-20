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
SIXEL = shutil.which("magick") or shutil.which("convert")  # png -> sixel (for non-Latin big text)
FONT_TTF = next((p for p in (
    os.path.expanduser("~/.local/share/fonts/SOV_HuaHlim-Bold.ttf"),
    os.path.expanduser("~/.local/share/fonts/SOV_HuaHlim.ttf"),
) if os.path.isfile(p)), None)
RESET = "\x1b[0m"
BLUE = "\x1b[1;38;5;39m"   # steady blue for the current line
DIM = "\x1b[2;37m"
SHOW_NEXT = any(a in ("--next", "-n") for a in sys.argv[1:])  # default: no next line
SHOW_PREV = any(a in ("--prev", "-p") for a in sys.argv[1:])  # default: no previous line


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


def wrap_center(line, cols):
    """Word-wrap `line` to fit `cols`, each row centred (plain-text fallback)."""
    rows, cur = [], ""
    for w in line.split(" "):
        trial = (cur + " " + w).strip()
        if not cur or width(trial) <= cols:
            cur = trial
        else:
            rows.append(cur)
            cur = w
    if cur:
        rows.append(cur)
    return [center(r, cols) for r in (rows or [line])]


def big(line, cols, rows):
    """Render `line` as large as possible with a thick block font (tty-clock). Long lines WRAP
    to multiple big block-rows (toilet -w cols) rather than shrinking to plain text — picks the
    largest font whose wrapped height fits, else the smallest block font (still big)."""
    if line and FIG and line.isascii():
        fonts = (None,) if FIG.endswith("figlet") else ("bigmono12", "bigmono9", "mono9")
        maxh = max(3, rows - 4)
        smallest = None
        for font in fonts:
            try:
                cmd = [FIG, "-w", str(cols)] + ([] if font is None else ["-f", font]) + [line]
                art = subprocess.run(cmd, capture_output=True, text=True, timeout=1).stdout.rstrip("\n").split("\n")
                art = [r for r in art if r.strip()] or art  # drop blank rows
                if not art:
                    continue
                smallest = art
                if len(art) <= maxh:
                    return [center(r, cols) for r in art]
            except Exception:
                pass
        if smallest:  # nothing fit height — use the smallest block font anyway (stays big)
            return [center(r, cols) for r in smallest]
    return wrap_center(line, cols)


def term_pixels():
    """(width_px, height_px) of the terminal, or (0,0) if unknown."""
    try:
        import fcntl, struct
        r, c, xp, yp = struct.unpack("HHHH", fcntl.ioctl(sys.stdout.fileno(), termios.TIOCGWINSZ, b"\0" * 8))
        return xp, yp
    except Exception:
        return 0, 0


def png_to_sixel(im, rgb):
    """Encode an RGBA image as a single-colour, TRANSPARENT sixel (P2=1): only pixels with
    alpha set are drawn, everything else stays the terminal background (no black box).
    img2sixel is broken here and ImageMagick paints transparent areas black, so we emit it."""
    px = im.load()
    w, h = im.size
    out = ["\x1bP0;1;0q", f'"1;1;{w};{h}',
           f"#1;2;{rgb[0] * 100 // 255};{rgb[1] * 100 // 255};{rgb[2] * 100 // 255}"]
    for y0 in range(0, h, 6):
        out.append("#1")
        for x in range(w):
            b = 0
            for dy in range(6):
                yy = y0 + dy
                if yy < h and px[x, yy][3] > 80:
                    b |= 1 << dy
            out.append(chr(63 + b))
        out.append("-")
    out.append("\x1b\\")
    return "".join(out)


_sixel_cache = {}


def render_sixel(text, cols, rows):
    """Render `text` big with FONT_TTF -> sixel (for Thai/non-Latin). Returns (sixel, cell_cols)
    auto-sized to ~90% width / 45% height, or (None, 0) if unavailable. Cached per (text,cols,rows)."""
    if not (FONT_TTF and text):
        return None, 0
    ckey = (text, cols, rows)
    if ckey in _sixel_cache:
        return _sixel_cache[ckey]
    try:
        from PIL import Image, ImageDraw, ImageFont

        def wrap_px(s, fnt, mw):
            out, cur = [], ""
            for ch in s:
                if not cur or fnt.getbbox(cur + ch)[2] <= mw:
                    cur += ch
                else:
                    out.append(cur)
                    cur = ch
            if cur:
                out.append(cur)
            return out or [s]

        xp, yp = term_pixels()
        if xp <= 0 or yp <= 0:
            xp, yp = cols * 8, rows * 17
        maxw, maxh = int(xp * 0.9), int(yp * 0.5)
        chosen = None
        for size in (240, 200, 160, 130, 104, 84, 66, 52, 40, 32):
            font = ImageFont.truetype(FONT_TTF, size)
            wl = wrap_px(text, font, maxw)
            asc, desc = font.getmetrics()
            lh = asc + desc
            if lh * len(wl) <= maxh:
                chosen = (font, wl, lh)
                break
        if not chosen:  # too long even at min size — wrap at min size anyway (stays big)
            font = ImageFont.truetype(FONT_TTF, 32)
            wl = wrap_px(text, font, maxw)
            chosen = (font, wl, sum(font.getmetrics()))
        font, wl, lh = chosen
        body = "\n".join(wl)
        w = max((font.getbbox(l)[2] for l in wl), default=10)
        im = Image.new("RGBA", (w + 24, lh * len(wl) + 24), (0, 0, 0, 0))  # transparent bg
        ImageDraw.Draw(im).multiline_text((12, 12), body, font=font, fill=(80, 180, 255, 255), align="center", spacing=0)
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
        six = png_to_sixel(im, (80, 180, 255))
        cell_cols = max(1, round(im.width / (xp / cols))) if xp > 0 else cols
        res = (six, cell_cols)
    except Exception:
        res = (None, 0)
    _sixel_cache[ckey] = res
    if len(_sixel_cache) > 8:
        _sixel_cache.pop(next(iter(_sixel_cache)))
    return res


def main():
    if not shutil.which("playerctl"):
        print("playerctl is not installed — run:  sudo pacman -S playerctl")
        return

    # `lyrics --edit` : open (or create) the .lrc for the current song in $EDITOR.
    if "--edit" in sys.argv or "-e" in sys.argv:
        artist, title = pctl("metadata", "artist"), pctl("metadata", "title")
        if not title:
            print("No song is playing.")
            return
        d = lyrics_dir()
        os.makedirs(d, exist_ok=True)
        # Edit the file that's actually used if one exists; otherwise create a TITLE-ONLY file
        # (artist from NetEase is often Chinese — title-only still matches via find_lrc fallback).
        path = find_lrc(d, artist, title)
        if not path:
            path = os.path.join(d, f"{title.replace('/', '_')}.lrc")
            with open(path, "w", encoding="utf-8") as f:
                f.write(f"[ti:{title}]\n[00:00.00]{title}\n[00:05.00]\n")
        editor = os.environ.get("EDITOR") or shutil.which("micro") or shutil.which("nano") or "vi"
        print(f"Editing {path}")
        subprocess.run([editor, path])
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

    d, song, lines, idx, last_state = lyrics_dir(), None, [], -1, None
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
                            open(os.path.join(d, f"{title.replace('/', '_')}.lrc"), "w", encoding="utf-8").write(txt)
                        except Exception:
                            pass
            cols, rows = shutil.get_terminal_size((80, 24))

            prev = nxt = status_line = ""
            ci = -2
            if not title:
                cur = "(nothing playing)"
            elif lines:
                ci = -1
                for i, (t, _) in enumerate(lines):
                    if t <= pos + 0.2:
                        ci = i
                    else:
                        break
                idx = ci
                cur = lines[ci][1] if ci >= 0 else "♪"
                prev = lines[ci - 1][1] if ci - 1 >= 0 else ""
                nxt = lines[ci + 1][1] if 0 <= ci + 1 < len(lines) else ""
            else:
                cur = title
                status_line = f"{artist}   ·   (no synced lyrics)"

            # Redraw only when something visible changes (sixel is expensive / flickers otherwise)
            state = (title, ci, cur, cols, rows)
            if state == last_state:
                time.sleep(0.1)
                continue
            last_state = state

            above = prev if SHOW_PREV else ""
            below = status_line or (nxt if SHOW_NEXT else "")

            # Thai / non-Latin -> render big with the TTF font as a sixel image; Latin -> block font
            six, six_cols = render_sixel(cur, cols, rows) if (cur and not cur.isascii()) else (None, 0)

            out = ["\x1b[H\x1b[2J"]
            if six:
                pad = max(0, rows // 2 - 5)
                out.append("\n" * pad)
                if above:
                    out.append(DIM + center(above, cols) + RESET + "\n\n")
                out.append(f"\x1b[{max(0, (cols - six_cols) // 2)}C")
                out.append(six)
                out.append("\n")
                if below:
                    out.append("\n" + DIM + center(below, cols) + RESET)
            else:
                block = big(cur or "♪", cols, rows)
                body = []
                if above:
                    body.append((DIM, center(above, cols)))
                    body.append(("", ""))
                for r in block:
                    body.append((BLUE, r))
                if below:
                    body.append(("", ""))
                    body.append((DIM, center(below, cols)))
                out.append("\n" * max(0, (rows - len(body)) // 2))
                for c, txt in body:
                    out.append(f"{c}{txt}{RESET}\n" if c else f"{txt}\n")
            sys.stdout.write("".join(out))
            sys.stdout.flush()
            time.sleep(0.1)
    except Exception:
        cleanup()


if __name__ == "__main__":
    main()
