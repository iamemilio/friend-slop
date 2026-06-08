#!/usr/bin/env bash
# Headless export — same entry point as the GitHub Actions release job.
# Usage: bash tools/run_godot_export.sh "Linux" build/linux/FriendSlop.x86_64
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "usage: $0 <export-preset-name> <export-output-path>" >&2
	exit 1
fi

EXPORT_PRESET="$1"
EXPORT_PATH="$2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/load_versions.sh
source "$ROOT/tools/load_versions.sh"
# shellcheck source=tools/ci_log.sh
source "$ROOT/tools/ci_log.sh"
load_versions "$ROOT/tools/versions.env"

BIN_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
GODOT_BIN="${GODOT_BIN:-$ROOT/.cache/godot/$BIN_NAME}"
EXPORT_TIMEOUT_SEC="${GODOT_EXPORT_TIMEOUT_SEC:-900}"
LOG_DIR="$ROOT/.cache/ci-logs"
LOG_FILE="$LOG_DIR/godot-export-$(echo "$EXPORT_PRESET" | tr ' ' '-' | tr '[:upper:]' '[:lower:]').log"

if [[ ! -x "$GODOT_BIN" ]]; then
	ci_log "ERROR: Godot not found at $GODOT_BIN (run tools/setup_godot_linux.sh)"
	exit 1
fi

mkdir -p "$LOG_DIR" "$(dirname "$ROOT/$EXPORT_PATH")"
cd "$ROOT"

ci_step_start "godot_export"
ci_log "Export preset: $EXPORT_PRESET"
ci_log "Export path: $EXPORT_PATH"
ci_log "Godot binary: $GODOT_BIN"
ci_log "Export timeout: ${EXPORT_TIMEOUT_SEC}s"
ci_log "Export log: $LOG_FILE"

godot_args=(--headless --path . --export-release "$EXPORT_PRESET" "$EXPORT_PATH")
if [[ "${GODOT_CI_VERBOSE:-}" == "1" ]]; then
	godot_args=(--verbose "${godot_args[@]}")
fi

_export_start=$SECONDS
(
	while true; do
		sleep 15
		ci_log "export still running ($((SECONDS - _export_start))s wall) ..."
		if [[ -f "$LOG_FILE" ]]; then
			last_line="$(tail -1 "$LOG_FILE" 2>/dev/null || true)"
			if [[ -n "$last_line" ]]; then
				ci_log "last godot output: $last_line"
			fi
		fi
	done
) &
HEARTBEAT_PID=$!

set +e
if command -v timeout >/dev/null 2>&1; then
	timeout "$EXPORT_TIMEOUT_SEC" "$GODOT_BIN" "${godot_args[@]}" >"$LOG_FILE" 2>&1
	exit_code=$?
else
	"$GODOT_BIN" "${godot_args[@]}" >"$LOG_FILE" 2>&1
	exit_code=$?
fi
set -e

kill "$HEARTBEAT_PID" 2>/dev/null || true
wait "$HEARTBEAT_PID" 2>/dev/null || true

if [[ -f "$LOG_FILE" ]]; then
	ci_log "Godot export output:"
	cat "$LOG_FILE" | sed 's/^/[godot] /'
fi

if [[ "$exit_code" -eq 124 ]]; then
	ci_log "ERROR: Godot export timed out after ${EXPORT_TIMEOUT_SEC}s"
	ci_step_end "godot_export"
	exit 1
fi

if [[ ! -f "$EXPORT_PATH" && "$exit_code" -ne 0 ]]; then
	ci_log "ERROR: Godot export failed (exit $exit_code) and output missing: $EXPORT_PATH"
	ci_step_end "godot_export"
	exit "$exit_code"
fi

if [[ "$exit_code" -ne 0 && -f "$EXPORT_PATH" ]]; then
	ci_log "WARN: Godot export exited $exit_code but artifact exists; treating as success"
elif [[ "$exit_code" -ne 0 ]]; then
	ci_log "ERROR: Godot export failed (exit $exit_code)"
	ci_step_end "godot_export"
	exit "$exit_code"
fi

ci_log "Export artifact: $EXPORT_PATH ($(du -h "$EXPORT_PATH" | awk '{print $1}'))"
ci_step_end "godot_export"
