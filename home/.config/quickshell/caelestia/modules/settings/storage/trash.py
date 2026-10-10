#!/usr/bin/env python3
"""Safely inspect or empty this user's freedesktop trash directories."""

from __future__ import annotations

import json
import os
import stat
import sys
from pathlib import Path


UID = os.getuid()
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()


def mount_points() -> list[Path]:
    mounts = {Path("/")}
    try:
        for line in Path("/proc/self/mountinfo").read_text(encoding="utf-8").splitlines():
            fields = line.split()
            if len(fields) > 4:
                path = fields[4]
                for escaped, char in (("\\040", " "), ("\\011", "\t"), ("\\012", "\n"), ("\\134", "\\")):
                    path = path.replace(escaped, char)
                if path.startswith("/"):
                    mounts.add(Path(path))
    except OSError:
        pass
    return sorted(mounts, key=str)


def trash_roots() -> list[Path]:
    roots = {DATA_HOME / "Trash"}
    for mount in mount_points():
        roots.add(mount / f".Trash-{UID}")
        roots.add(mount / ".Trash" / str(UID))
    return sorted(roots, key=str)


def safe_children(directory: Path) -> list[Path]:
    if directory.is_symlink() or not directory.is_dir():
        return []
    return list(directory.iterdir())


def is_owned_trash_root(root: Path) -> bool:
    try:
        return not root.is_symlink() and root.is_dir() and root.stat().st_uid == UID
    except OSError:
        return False


def inspect() -> dict:
    roots = []
    count = 0
    errors = []
    for root in trash_roots():
        if not is_owned_trash_root(root):
            continue
        try:
            files = safe_children(root / "files")
            item_count = len(files)
            roots.append({"path": str(root), "count": item_count})
            count += item_count
        except OSError as error:
            errors.append(f"{root}: {error}")
    return {"ok": not errors, "count": count, "roots": roots, "errors": errors}


def remove_tree(path: Path, device: int) -> None:
    if path.stat(follow_symlinks=False).st_dev != device:
        raise OSError("refusing to cross a mounted filesystem")
    with os.scandir(path) as entries:
        for entry in entries:
            child = Path(entry.path)
            metadata = entry.stat(follow_symlinks=False)
            if metadata.st_dev != device:
                raise OSError(f"refusing to cross mounted filesystem at {child}")
            if stat.S_ISDIR(metadata.st_mode):
                remove_tree(child, device)
            else:
                child.unlink()
    path.rmdir()


def remove_entry(path: Path, device: int) -> None:
    metadata = path.stat(follow_symlinks=False)
    if metadata.st_dev != device:
        raise OSError("refusing to cross a mounted filesystem")
    if stat.S_ISDIR(metadata.st_mode):
        remove_tree(path, device)
    else:
        path.unlink()


def empty() -> dict:
    removed = 0
    errors = []
    for root in trash_roots():
        if not is_owned_trash_root(root):
            continue
        files_dir = root / "files"
        info_dir = root / "info"
        try:
            device = files_dir.stat().st_dev if files_dir.is_dir() and not files_dir.is_symlink() else None
            for path in safe_children(files_dir):
                try:
                    remove_entry(path, device)
                    removed += 1
                except OSError as error:
                    errors.append(f"{path}: {error}")
            for path in safe_children(info_dir):
                if path.name.endswith(".trashinfo"):
                    try:
                        if path.is_dir() and not path.is_symlink():
                            errors.append(f"{path}: metadata entry is a directory")
                        else:
                            path.unlink()
                    except OSError as error:
                        errors.append(f"{path}: {error}")
        except OSError as error:
            errors.append(f"{root}: {error}")
    return {"ok": not errors, "removed": removed, "errors": errors}


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    result = empty() if action == "empty" else inspect()
    print(json.dumps(result, ensure_ascii=False))
    if not result["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
