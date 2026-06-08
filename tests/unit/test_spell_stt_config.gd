class_name TestSpellSttConfig
extends RefCounted

const ConfigScript := preload("res://scripts/spells/gdvosk_extension_config.gd")

const UPSTREAM_MANIFEST := """
windows.debug.x86_64 = "res://addons/gdvosk/lib/windows/x86_64/libgdvosk-d.dll"
windows.release.x86_64 = "res://addons/gdvosk/lib/windows/x86_64/libgdvosk.dll"
"""


func run() -> int:
	var failures := 0
	failures += _test_upstream_manifest_blocks_editor_stt()
	failures += _test_regression_editor_library_keys_required()
	return failures


func _test_upstream_manifest_blocks_editor_stt() -> int:
	var issue := ConfigScript.validate_manifest(UPSTREAM_MANIFEST)
	if issue.is_empty():
		push_error("Expected upstream gdvosk manifest to fail editor-entry validation")
		return 1
	if not issue.contains("Play-in-Editor"):
		push_error("Expected manifest validation to explain Play-in-Editor requirement")
		return 1
	if not issue.contains("make setup-voice"):
		push_error("Expected manifest validation to mention make setup-voice")
		return 1
	return 0


func _test_regression_editor_library_keys_required() -> int:
	var missing := ConfigScript.get_missing_editor_library_keys(UPSTREAM_MANIFEST)
	if missing.size() != ConfigScript.REQUIRED_EDITOR_LIBRARY_KEYS.size():
		push_error(
			"Expected upstream manifest to miss all editor library keys, got: %s"
			% ", ".join(missing)
		)
		return 1
	return 0
