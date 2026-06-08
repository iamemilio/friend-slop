#!/usr/bin/env bash
# Installs gdvosk GDExtension and a small English Vosk model for FriendSlop.
# Run from repo root: bash tools/setup_gdvosk.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.cache/voice-setup"
ADDONS_DIR="$ROOT/addons/gdvosk"
MODEL_DIR="$ROOT/models/vosk"

GDVOSK_URL="https://github.com/Nihlus/gdvosk/releases/download/v1.0/gdvosk_1.0.0.zip"
MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"

mkdir -p "$CACHE" "$(dirname "$ADDONS_DIR")" "$(dirname "$MODEL_DIR")"

download_if_missing() {
	local url="$1"
	local dest="$2"
	if [[ -f "$dest" ]]; then
		echo "Using cached $(basename "$dest")"
		return
	fi
	echo "Downloading $url ..."
	curl -fsSL -o "$dest" "$url"
}

GDVOSK_ZIP="$CACHE/gdvosk_1.0.0.zip"
MODEL_ZIP="$CACHE/vosk-model-small-en-us-0.15.zip"

download_if_missing "$GDVOSK_URL" "$GDVOSK_ZIP"
download_if_missing "$MODEL_URL" "$MODEL_ZIP"

find_gdvosk_root() {
	local search_root="$1"
	local candidates=(
		"$search_root/addons/gdvosk"
		"$search_root/gdvosk"
		"$search_root"
	)
	local candidate
	for candidate in "${candidates[@]}"; do
		if [[ -f "$candidate/gdvosk.gdextension" ]]; then
			echo "$candidate"
			return 0
		fi
	done
	return 1
}

if [[ ! -f "$ADDONS_DIR/gdvosk.gdextension" ]]; then
	echo "Extracting gdvosk to addons/ ..."
	TEMP_EXTRACT="$(mktemp -d)"
	trap 'rm -rf "$TEMP_EXTRACT"' EXIT
	unzip -q "$GDVOSK_ZIP" -d "$TEMP_EXTRACT"
	SOURCE="$(find_gdvosk_root "$TEMP_EXTRACT")"
	rm -rf "$ADDONS_DIR"
	cp -R "$SOURCE" "$ADDONS_DIR"
	echo "gdvosk installed to $ADDONS_DIR"
else
	echo "gdvosk already installed at $ADDONS_DIR"
fi

if [[ ! -f "$ADDONS_DIR/lib/linux/x86_64/libgdvosk-d.so" ]]; then
	echo "error: gdvosk Linux libraries missing under $ADDONS_DIR/lib/linux/x86_64/" >&2
	exit 1
fi

if [[ ! -f "$ADDONS_DIR/lib/windows/x86_64/libgdvosk-d.dll" ]]; then
	echo "error: gdvosk Windows libraries missing under $ADDONS_DIR/lib/windows/x86_64/" >&2
	exit 1
fi

if [[ ! -d "$MODEL_DIR/am" ]]; then
	echo "Extracting Vosk model to models/vosk/ ..."
	TEMP_MODEL="$(mktemp -d)"
	trap 'rm -rf "$TEMP_MODEL"' EXIT
	unzip -q "$MODEL_ZIP" -d "$TEMP_MODEL"
	INNER="$(find "$TEMP_MODEL" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
	if [[ -z "$INNER" ]]; then
		echo "error: Vosk model zip was empty." >&2
		exit 1
	fi
	rm -rf "$MODEL_DIR"
	cp -R "$INNER" "$MODEL_DIR"
	echo "Vosk model installed to $MODEL_DIR"
else
	echo "Vosk model already installed at $MODEL_DIR"
fi

echo ""
echo "Done. gdvosk and Vosk model are ready for export."
