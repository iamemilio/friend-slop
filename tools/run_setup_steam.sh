#!/usr/bin/env bash
# Installs GodotSteam GDExtension for CI and release exports (logged, same pins as local dev).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/ci_log.sh
source "$ROOT/tools/ci_log.sh"

ci_step_start "setup_steam"

if [[ -f "$ROOT/addons/godotsteam/godotsteam.gdextension" ]]; then
	ci_log "GodotSteam already present (addons/godotsteam)"
	bash "$ROOT/tools/verify_godotsteam.sh"
	ci_step_end "setup_steam"
	exit 0
fi

for cmd in curl unzip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		if [[ "$(id -u)" -eq 0 ]]; then
			export DEBIAN_FRONTEND=noninteractive
			apt-get update
			apt-get install -y curl unzip
			break
		fi
		if command -v sudo >/dev/null 2>&1; then
			sudo DEBIAN_FRONTEND=noninteractive apt-get update
			sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip
			break
		fi
		ci_log "ERROR: need curl and unzip to download GodotSteam"
		exit 1
	fi
done

ci_log "Running tools/setup_godotsteam.sh (~27 MB on first download)"
bash "$ROOT/tools/setup_godotsteam.sh"
bash "$ROOT/tools/verify_godotsteam.sh"
ci_step_end "setup_steam"
