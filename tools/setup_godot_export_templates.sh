#!/usr/bin/env bash
# Downloads pinned Godot export templates into .cache/ and links them for the editor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/load_versions.sh
source "$ROOT/tools/load_versions.sh"
# shellcheck source=tools/ci_log.sh
source "$ROOT/tools/ci_log.sh"
load_versions "$ROOT/tools/versions.env"

ci_step_start "setup_godot_export_templates"

CACHE_DIR="$ROOT/.cache/godot-export-templates"
TEMPLATE_VERSION_DIR="${GODOT_VERSION}.stable"
TEMPLATE_CACHE_PATH="$CACHE_DIR/$TEMPLATE_VERSION_DIR"
TPZ_NAME="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
TPZ_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/${TPZ_NAME}"
TPZ_PATH="$CACHE_DIR/$TPZ_NAME"
USER_TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${TEMPLATE_VERSION_DIR}"

mkdir -p "$CACHE_DIR" "$(dirname "$USER_TEMPLATE_DIR")"

if [[ -d "$TEMPLATE_CACHE_PATH" && -n "$(ls -A "$TEMPLATE_CACHE_PATH" 2>/dev/null || true)" ]]; then
	ci_log "Using cached export templates: $TEMPLATE_CACHE_PATH"
else
	download() {
		local dest="$1"
		local url="$2"
		if command -v curl >/dev/null 2>&1; then
			curl -fsSL -o "$dest" "$url"
		elif command -v wget >/dev/null 2>&1; then
			wget -q -O "$dest" "$url"
		else
			ci_log "ERROR: need curl or wget to download export templates"
			exit 1
		fi
	}

	if [[ ! -f "$TPZ_PATH" ]]; then
		ci_log "Downloading export templates from $TPZ_URL"
		download "$TPZ_PATH" "$TPZ_URL"
		ci_log "Download complete: $(du -h "$TPZ_PATH" | awk '{print $1}')"
	else
		ci_log "Using cached tpz: $TPZ_PATH"
	fi

	if ! command -v unzip >/dev/null 2>&1; then
		ci_log "ERROR: unzip is required to extract export templates"
		exit 1
	fi

	TEMP_EXTRACT="$(mktemp -d)"
	trap 'rm -rf "$TEMP_EXTRACT"' EXIT
	ci_log "Extracting $TPZ_NAME ..."
	unzip -q "$TPZ_PATH" -d "$TEMP_EXTRACT"
	rm -rf "$TEMPLATE_CACHE_PATH"
	mkdir -p "$TEMPLATE_CACHE_PATH"
	if [[ -d "$TEMP_EXTRACT/templates" ]]; then
		cp -a "$TEMP_EXTRACT/templates/." "$TEMPLATE_CACHE_PATH/"
	else
		ci_log "ERROR: templates/ folder missing inside $TPZ_NAME"
		exit 1
	fi
	ci_log "Installed export templates to $TEMPLATE_CACHE_PATH"
fi

rm -rf "$USER_TEMPLATE_DIR"
ln -sfn "$TEMPLATE_CACHE_PATH" "$USER_TEMPLATE_DIR"
ci_log "Linked export templates -> $USER_TEMPLATE_DIR"
ci_step_end "setup_godot_export_templates"
