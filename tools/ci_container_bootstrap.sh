#!/usr/bin/env bash
# Installs make + python3 in slim CI images (e.g. barichello/godot-ci) when missing.
set -euo pipefail

need_install=false
if ! command -v make >/dev/null 2>&1; then
	need_install=true
fi
if ! command -v python3 >/dev/null 2>&1; then
	need_install=true
fi

if [[ "$need_install" != "true" ]]; then
	echo "CI container bootstrap: make and python3 already present"
	exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
	echo "error: CI container bootstrap needs root (apt-get). Run as root in godot-ci." >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends make python3 python3-pip python3-venv
echo "CI container bootstrap: installed make, python3, python3-pip, and python3-venv"
