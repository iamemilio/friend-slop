#!/usr/bin/env bash
# Verifies GodotSteam GDExtension layout. Run from repo root: bash tools/verify_godotsteam.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/load_versions.sh
source "$ROOT/tools/load_versions.sh"
load_versions "$ROOT/tools/versions.env"

ADDONS_DIR="$ROOT/addons/godotsteam"
GDE="$ADDONS_DIR/godotsteam.gdextension"

if [[ ! -f "$GDE" ]]; then
	echo "error: GodotSteam not installed. Run: make setup-steam" >&2
	exit 1
fi

if [[ ! -f "$ADDONS_DIR/linux64/libgodotsteam.linux.template_debug.x86_64.so" ]]; then
	echo "error: GodotSteam Linux libs missing. Re-run: make setup-steam" >&2
	exit 1
fi

if [[ ! -f "$ADDONS_DIR/win64/libgodotsteam.windows.template_debug.x86_64.dll" ]]; then
	echo "error: GodotSteam Windows libs missing. Re-run: make setup-steam" >&2
	exit 1
fi

if [[ ! -f "$ROOT/steam_appid.txt" ]]; then
	echo "error: steam_appid.txt missing at repo root." >&2
	exit 1
fi

echo "GodotSteam OK (${GODOTSTEAM_VERSION}, ${GODOTSTEAM_GDE_RELEASE_TAG})"
