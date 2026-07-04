#!/usr/bin/env python3
"""Restore GDExtension manifests left disabled by headless test runs."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

EXTENSION_PAIRS: tuple[tuple[Path, Path], ...] = (
    (
        ROOT / "addons" / "gdvosk" / "gdvosk.gdextension",
        ROOT / "addons" / "gdvosk" / "gdvosk.gdextension.disabled",
    ),
    (
        ROOT / "addons" / "godotsteam" / "godotsteam.gdextension",
        ROOT / "addons" / "godotsteam" / "godotsteam.gdextension.disabled",
    ),
)


def restore_extensions() -> list[str]:
    restored: list[str] = []
    for active, disabled in EXTENSION_PAIRS:
        if disabled.exists() and not active.exists():
            disabled.rename(active)
            restored.append(str(active.relative_to(ROOT)))
    return restored


def main() -> int:
    restored = restore_extensions()
    if restored:
        print("Restored GDExtension manifests:")
        for path in restored:
            print(f"  - {path}")
        print("Fully quit Godot, reopen the project, then try speech again.")
        return 0
    print("All GDExtension manifests are already enabled.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
