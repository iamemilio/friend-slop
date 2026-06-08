#!/usr/bin/env bash
# Local Ubuntu/WSL smoke test mirroring CI make targets.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== CI smoke (linux) =="
echo "OS: $(uname -a)"

if [[ -z "${CI_SMOKE_IN_CONTAINER:-}" ]] && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	echo ""
	echo "-- godot-ci container --"
	docker run --rm -e CI_SMOKE_IN_CONTAINER=1 -v "$ROOT:/project" -w /project barichello/godot-ci:4.6.3 bash -lc '
		set -euo pipefail
		bash tools/ci_smoke_linux.sh
	'
	echo "godot-ci container smoke: OK"
	exit 0
fi

echo ""
echo "-- native linux --"
if ! command -v make >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
	if [[ "$(id -u)" -eq 0 ]] && [[ -f tools/ci_container_bootstrap.sh ]]; then
		bash tools/ci_container_bootstrap.sh
	else
		echo "error: need make and python3 in PATH (or run as root in godot-ci)" >&2
		exit 1
	fi
fi

if ! python3 -m venv /tmp/friend-slop-venv-check >/dev/null 2>&1; then
	echo "Installing python3-venv for local smoke test..."
	if [[ "$(id -u)" -eq 0 ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get update
		DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv
	elif command -v sudo >/dev/null 2>&1; then
		sudo DEBIAN_FRONTEND=noninteractive apt-get update
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv
	else
		echo "error: python3-venv required (sudo apt install python3-venv)" >&2
		exit 1
	fi
	rm -rf /tmp/friend-slop-venv-check
fi

make verify-pinned-versions
make setup-dev
make lint

if command -v godot >/dev/null 2>&1; then
	make test GODOT=godot
else
	echo "Skipping make test (godot not in PATH; run inside godot-ci via Docker for full coverage)"
fi

echo "native linux smoke: OK"
