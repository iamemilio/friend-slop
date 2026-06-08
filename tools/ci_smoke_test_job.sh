#!/usr/bin/env bash
# Local smoke test for the GitHub Actions "Godot unit tests" job.
#
# Usage:
#   bash tools/ci_smoke_test_job.sh
#     Prefers Docker ubuntu:24.04 (same base as GHA). Falls back to native Linux/WSL.
#
#   CI_SMOKE_NATIVE=1 bash tools/ci_smoke_test_job.sh
#     Run the job steps on the current machine (WSL, Linux, or inside Docker).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=tools/ci_log.sh
source tools/ci_log.sh

if [[ -z "${CI_SMOKE_NATIVE:-}" ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	ci_log "Launching ubuntu:24.04 container (mirrors GHA test job)"
	docker run --rm -e CI_SMOKE_NATIVE=1 -e GODOT_CI_VERBOSE="${GODOT_CI_VERBOSE:-}" -v "$ROOT:/project" -w /project ubuntu:24.04 bash -lc '
		set -euo pipefail
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y -qq ca-certificates curl unzip libfontconfig1
		bash tools/ci_smoke_test_job.sh
	'
	ci_log "CI test job smoke: OK"
	exit 0
fi

ci_log "== CI test job smoke (native) =="
ci_log "OS: $(uname -a)"

for cmd in curl unzip; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		ci_log "ERROR: $cmd required (apt install $cmd)"
		exit 1
	fi
done

JOB_START=$SECONDS
bash tools/setup_godot_linux.sh
bash tools/run_godot_import.sh
bash tools/run_godot_tests.sh
ci_log "CI test job smoke finished in $((SECONDS - JOB_START))s"
