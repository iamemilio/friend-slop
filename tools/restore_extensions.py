#!/usr/bin/env python3
"""Sync GDExtension manifests for the active Godot binary and test runs."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSIONS_ENV = ROOT / "tools" / "versions.env"

GDVOSK_ACTIVE = ROOT / "addons" / "gdvosk" / "gdvosk.gdextension"
GDVOSK_DISABLED = ROOT / "addons" / "gdvosk" / "gdvosk.gdextension.disabled"
GODOTSTEAM_ACTIVE = ROOT / "addons" / "godotsteam" / "godotsteam.gdextension"
GODOTSTEAM_DISABLED = ROOT / "addons" / "godotsteam" / "godotsteam.gdextension.disabled"


def _read_versions_env(key: str) -> str:
	if not VERSIONS_ENV.exists():
		return ""
	for line in VERSIONS_ENV.read_text(encoding="utf-8").splitlines():
		stripped = line.strip()
		if not stripped or stripped.startswith("#") or "=" not in stripped:
			continue
		line_key, value = stripped.split("=", 1)
		if line_key.strip() == key:
			return value.strip()
	return ""


def find_godot_binary() -> Path | None:
	env_path = os.environ.get("GODOT_PATH", "").strip()
	if env_path:
		candidate = Path(env_path)
		if candidate.exists():
			return candidate

	pinned_win = _read_versions_env("GODOT_EDITOR_WIN")
	if pinned_win:
		candidate = Path(pinned_win)
		if candidate.exists():
			return candidate

	settings_path = ROOT / ".vscode" / "settings.json"
	if settings_path.exists():
		data = json.loads(settings_path.read_text(encoding="utf-8"))
		editor_path = data.get("godotTools.editorPath", "")
		if editor_path:
			candidate = Path(str(editor_path))
			if candidate.exists():
				return candidate

	which_godot = shutil.which("godot")
	if which_godot:
		return Path(which_godot)
	return None


def is_godotsteam_editor(godot: Path) -> bool:
	return "godotsteam" in godot.name.lower()


def _restore_if_disabled(active: Path, disabled: Path) -> str | None:
	if disabled.exists() and not active.exists():
		disabled.rename(active)
		return str(active.relative_to(ROOT))
	return None


def sync_godotsteam_gdextension(godot: Path | None = None) -> list[str]:
	changes: list[str] = []
	if godot is None:
		godot = find_godot_binary()

	if godot is not None and is_godotsteam_editor(godot):
		if GODOTSTEAM_ACTIVE.exists():
			GODOTSTEAM_ACTIVE.rename(GODOTSTEAM_DISABLED)
			uid = GODOTSTEAM_ACTIVE.with_suffix(".gdextension.uid")
			if uid.exists():
				uid.rename(GODOTSTEAM_DISABLED.with_suffix(".gdextension.uid"))
			changes.append(
				"Disabled addons/godotsteam/godotsteam.gdextension "
				+ "(GodotSteam editor already includes Steam)."
			)
		return changes

	restored = _restore_if_disabled(GODOTSTEAM_ACTIVE, GODOTSTEAM_DISABLED)
	if restored is not None:
		uid_disabled = GODOTSTEAM_DISABLED.with_suffix(".gdextension.uid")
		uid_active = GODOTSTEAM_ACTIVE.with_suffix(".gdextension.uid")
		if uid_disabled.exists() and not uid_active.exists():
			uid_disabled.rename(uid_active)
		changes.append(f"Restored {restored}")
	return changes


def sync_extensions(godot: Path | None = None) -> list[str]:
	changes: list[str] = []
	restored = _restore_if_disabled(GDVOSK_ACTIVE, GDVOSK_DISABLED)
	if restored is not None:
		changes.append(f"Restored {restored}")
	changes.extend(sync_godotsteam_gdextension(godot))
	return changes


def restore_extensions(godot: Path | None = None) -> list[str]:
	"""Back-compat alias for sync_extensions()."""
	return sync_extensions(godot)


def main() -> int:
	changes = sync_extensions(find_godot_binary())
	if changes:
		print("Synced GDExtension manifests:")
		for message in changes:
			print(f"  - {message}")
		print("Fully quit Godot, reopen the project, then run again.")
		return 0
	print("GDExtension manifests already match the active Godot binary.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
