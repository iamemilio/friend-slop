#!/usr/bin/env python3
"""Package godot-steam-voice from a local clone into addons/godot-steam-voice/."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SRC = ROOT / "vendor" / "godot-steam-voice"
DEFAULT_OUT = ROOT / "addons" / "godot-steam-voice"
PACKAGE_SCRIPT = "tools/package_addon.py"
REPO_URL = "https://github.com/iamemilio/godot-steam-voice.git"


def _ensure_source(src: Path, clone: bool) -> None:
    if src.is_dir() and (src / PACKAGE_SCRIPT).is_file():
        return
    if not clone:
        raise SystemExit(
            f"Source not found at {src}. Clone with:\n"
            f"  git clone {REPO_URL} {src}\n"
            f"Or run: python {Path(__file__).name} --clone"
        )
    src.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", "--depth", "1", REPO_URL, str(src)], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync packaged godot-steam-voice addon")
    parser.add_argument(
        "--src",
        type=Path,
        default=DEFAULT_SRC,
        help=f"Library repo root (default: {DEFAULT_SRC})",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"Packaged addon output (default: {DEFAULT_OUT})",
    )
    parser.add_argument(
        "--clone",
        action="store_true",
        help=f"Clone {REPO_URL} into --src if missing",
    )
    args = parser.parse_args()
    _ensure_source(args.src, args.clone)
    package = args.src / PACKAGE_SCRIPT
    proc = subprocess.run(
        [sys.executable, str(package), "--out", str(args.out)],
        cwd=str(args.src),
    )
    if proc.returncode != 0:
        return proc.returncode

    # package_addon.py touches addons/.gdignore — remove so Godot scans addons/
    spurious_gdignore = args.out.parent / ".gdignore"
    if spurious_gdignore.is_file():
        spurious_gdignore.unlink()

    version_path = args.out / "VERSION.txt"
    rev = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=str(args.src),
        capture_output=True,
        text=True,
        check=False,
    )
    short_hash = rev.stdout.strip() if rev.returncode == 0 else "unknown"
    version_path.write_text(
        f"godot-steam-voice @ {short_hash}\n"
        f"synced from {REPO_URL}\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
