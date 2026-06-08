#!/usr/bin/env bash
# Local smoke test for the GitHub Actions release export job.
#
# Usage:
#   bash tools/ci_smoke_release_job.sh
#     Docker ubuntu:24.04 by default (same base as GHA).
#
#   CI_SMOKE_NATIVE=1 bash tools/ci_smoke_release_job.sh
#     Run on the current machine.
#
# Env:
#   RELEASE_SMOKE_PRESET   Export preset (default: Linux)
#   RELEASE_SMOKE_PATH     Output path (default: build/linux/FriendSlop.x86_64)
#   RELEASE_SMOKE_SKIP_VOICE=1  Skip voice setup (faster, STT omitted from build)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=tools/ci_log.sh
source tools/ci_log.sh

PRESET="${RELEASE_SMOKE_PRESET:-Linux}"
EXPORT_PATH="${RELEASE_SMOKE_PATH:-build/linux/FriendSlop.x86_64}"

if [[ -z "${CI_SMOKE_NATIVE:-}" ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	ci_log "Launching ubuntu:24.04 container (mirrors GHA release job)"
	docker run --rm \
		-e CI_SMOKE_NATIVE=1 \
		-e GODOT_CI_VERBOSE="${GODOT_CI_VERBOSE:-1}" \
		-e RELEASE_SMOKE_PRESET="$PRESET" \
		-e RELEASE_SMOKE_PATH="$EXPORT_PATH" \
		-e RELEASE_SMOKE_SKIP_VOICE="${RELEASE_SMOKE_SKIP_VOICE:-0}" \
		-v "$ROOT:/project" -w /project ubuntu:24.04 bash -lc '
		set -euo pipefail
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y -qq ca-certificates curl unzip zip libfontconfig1
		bash tools/ci_smoke_release_job.sh
	'
	ci_log "CI release job smoke: OK"
	exit 0
fi

ci_log "== CI release job smoke (native) =="
ci_log "Preset: $PRESET"
ci_log "Output: $EXPORT_PATH"
ci_log "OS: $(uname -a)"

JOB_START=$SECONDS
bash tools/setup_godot_linux.sh
bash tools/setup_godot_export_templates.sh
if [[ "${RELEASE_SMOKE_SKIP_VOICE:-}" != "1" ]]; then
	bash tools/run_setup_voice.sh
else
	ci_log "Skipping voice setup (RELEASE_SMOKE_SKIP_VOICE=1)"
fi
bash tools/run_godot_import.sh
bash tools/run_godot_export.sh "$PRESET" "$EXPORT_PATH"
ci_log "CI release job smoke finished in $((SECONDS - JOB_START))s"
