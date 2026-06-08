#!/usr/bin/env python3
"""Run gdlint and Godot unit tests. Exit 0 on success, 1 on failure."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GDVOSK_GDEXTENSION = ROOT / "addons" / "gdvosk" / "gdvosk.gdextension"
GDVOSK_GDEXTENSION_DISABLED = ROOT / "addons" / "gdvosk" / "gdvosk.gdextension.disabled"
# Windows STATUS_ACCESS_VIOLATION when gdvosk unloads after headless test runs.
GDVOSK_CRASH_EXIT = 3221225477
GDVOSK_EDITOR_LIBRARY_KEYS = (
    "windows.editor.x86_64",
    "windows.editor.x86_32",
    "linux.editor.x86_64",
    "macos.editor",
)


def _validate_gdvosk_manifest() -> str | None:
    path = GDVOSK_GDEXTENSION
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    missing = [key for key in GDVOSK_EDITOR_LIBRARY_KEYS if f"{key} =" not in text]
    if not missing:
        return None
    return (
        "gdvosk.gdextension is missing editor library entries: "
        + ", ".join(missing)
        + ". Re-run tools/setup_gdvosk.ps1."
    )


def _disable_gdvosk_for_tests() -> bool:
    if not GDVOSK_GDEXTENSION.exists():
        return False
    if GDVOSK_GDEXTENSION_DISABLED.exists():
        GDVOSK_GDEXTENSION_DISABLED.unlink()
    GDVOSK_GDEXTENSION.rename(GDVOSK_GDEXTENSION_DISABLED)
    return True


def _restore_gdvosk_after_tests(was_disabled: bool) -> None:
    if not was_disabled:
        return
    if GDVOSK_GDEXTENSION_DISABLED.exists() and not GDVOSK_GDEXTENSION.exists():
        GDVOSK_GDEXTENSION_DISABLED.rename(GDVOSK_GDEXTENSION)


def _normalize_test_exit(returncode: int, stdout: str, stderr: str) -> int:
    combined = f"{stdout}\n{stderr}"
    if returncode == 0:
        return 0
    if returncode == GDVOSK_CRASH_EXIT and "All tests passed." in combined:
        return 0
    if "test(s) failed." in combined:
        return 1
    return returncode


def _find_godot() -> Path | None:
    env_path = os.environ.get("GODOT_PATH", "").strip()
    if env_path:
        candidate = Path(env_path)
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
    return None


def _find_gdlint() -> Path:
    scripts_dir = subprocess.check_output(
        [sys.executable, "-c", "import sysconfig; print(sysconfig.get_path('scripts'))"],
        text=True,
    ).strip()
    for name in ("gdlint.exe", "gdlint"):
        candidate = Path(scripts_dir) / name
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "gdlint not found. Install with: python -m pip install -r requirements-dev.txt"
    )


def run_checks() -> tuple[int, str]:
    output_lines: list[str] = []

    gdlint = _find_gdlint()
    output_lines.append("Running GDScript lint...")
    lint_proc = subprocess.run(
        [str(gdlint), "."],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    output_lines.append(lint_proc.stdout)
    output_lines.append(lint_proc.stderr)
    if lint_proc.returncode != 0:
        return lint_proc.returncode, "\n".join(line for line in output_lines if line)

    manifest_issue = _validate_gdvosk_manifest()
    if manifest_issue is not None:
        output_lines.append(manifest_issue)
        return 1, "\n".join(line for line in output_lines if line)

    godot = _find_godot()
    if godot is None:
        message = (
            "Godot executable not found. Set GODOT_PATH or "
            "godotTools.editorPath in .vscode/settings.json"
        )
        output_lines.append(message)
        return 1, "\n".join(output_lines)

    output_lines.append("Running Godot unit tests...")
    gdvosk_disabled = _disable_gdvosk_for_tests()
    try:
        test_proc = subprocess.run(
            [
                str(godot),
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                "res://tests/run_tests.gd",
            ],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
    finally:
        _restore_gdvosk_after_tests(gdvosk_disabled)
    output_lines.append(test_proc.stdout)
    output_lines.append(test_proc.stderr)
    exit_code = _normalize_test_exit(
        test_proc.returncode, test_proc.stdout, test_proc.stderr
    )
    return exit_code, "\n".join(line for line in output_lines if line)


def main() -> int:
    code, _output = run_checks()
    if code != 0:
        print(_output, file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
