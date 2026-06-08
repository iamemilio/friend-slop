# Reads tools/versions.env. PYTHON is set in the root Makefile before this include.
versions.env := tools/versions.env
read_version = $(PYTHON) tools/read_version.py

GODOT_VERSION := $(shell $(read_version) GODOT_VERSION)
GDVOSK_RELEASE_TAG := $(shell $(read_version) GDVOSK_RELEASE_TAG)
GDVOSK_ZIP := $(shell $(read_version) GDVOSK_ZIP)
VOSK_MODEL_ZIP := $(shell $(read_version) VOSK_MODEL_ZIP)
