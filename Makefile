SHELL := /bin/bash
.PHONY: help setup setup-dev setup-voice lint test test-ci release-ci check import verify-pinned-versions verify-voice ci-container-bootstrap

ifeq ($(OS),Windows_NT)
PYTHON ?= python
VENV_PY := .venv/Scripts/python.exe
else
PYTHON ?= python3
VENV_PY := .venv/bin/python
endif

ifneq ($(wildcard $(VENV_PY)),)
RUN_PYTHON := $(VENV_PY)
else
RUN_PYTHON := $(PYTHON)
endif

include tools/versions.mk

GODOT ?= godot

help:
	@echo "FriendSlop dev targets (Godot $(GODOT_VERSION))"
	@echo ""
	@echo "  make setup                 Python tooling + voice deps (full local setup)"
	@echo "  make setup-dev             pip install -r requirements-dev.txt (uses .venv)"
	@echo "  make setup-voice           gdvosk + Vosk model (~500 MB first run)"
	@echo "  make lint                  gdlint via tools/run_checks.py"
	@echo "  make test                  Godot unit tests via tools/run_checks.py"
	@echo "  make test-ci               smoke-test the GitHub Actions test job locally"
	@echo "  make release-ci            smoke-test the GitHub Actions release export (Linux)"
	@echo "  make check                 lint + test"
	@echo "  make import                godot --headless --import"
	@echo "  make verify-pinned-versions  CI guard: workflows match tools/versions.env"
	@echo "  make verify-voice          quick file check for gdvosk install"
	@echo ""
	@echo "Override Godot binary: make test GODOT=/path/to/godot"
	@echo "Pinned versions live in tools/versions.env"

setup: setup-dev setup-voice

setup-dev:
	@$(PYTHON) -m venv .venv || ( \
		echo "error: could not create .venv (on Ubuntu: sudo apt install python3-venv)" >&2; \
		exit 1 \
	)
	$(VENV_PY) -m pip install --disable-pip-version-check -U pip
	$(VENV_PY) -m pip install --disable-pip-version-check -r requirements-dev.txt

setup-voice:
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File tools/setup_gdvosk.ps1
else
	bash tools/setup_gdvosk.sh
endif

lint:
	$(RUN_PYTHON) tools/run_checks.py --lint-only

test:
	GODOT_PATH="$(GODOT)" $(RUN_PYTHON) tools/run_checks.py --tests-only

test-ci:
	bash tools/ci_smoke_test_job.sh

release-ci:
	bash tools/ci_smoke_release_job.sh

check: lint test

import:
	"$(GODOT)" --headless --path . --import

ci-container-bootstrap:
	bash tools/ci_container_bootstrap.sh

verify-pinned-versions:
	$(PYTHON) tools/check_pinned_versions.py

verify-voice:
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File tools/verify_gdvosk.ps1
else
	@test -f addons/gdvosk/gdvosk.gdextension || \
		(echo "gdvosk missing. Run: make setup-voice" >&2; exit 1)
	@test -f addons/gdvosk/lib/linux/x86_64/libgdvosk-d.so || \
		(echo "gdvosk Linux libs missing. Run: make setup-voice" >&2; exit 1)
	@test -d models/vosk/am || \
		(echo "Vosk model missing. Run: make setup-voice" >&2; exit 1)
	@grep -q 'windows\.editor\.x86_64' addons/gdvosk/gdvosk.gdextension || \
		(echo "gdvosk.gdextension needs editor entries. Run: make setup-voice" >&2; exit 1)
	@echo "Voice dependencies OK ($(GDVOSK_ZIP), $(VOSK_MODEL_ZIP))"
endif
