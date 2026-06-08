extends SceneTree

## Quick check: godot --path . --script res://tests/check_gdvosk.gd


func _init() -> void:
	call_deferred("_check")


func _check() -> void:
	print("Godot version: ", Engine.get_version_info())
	var manifest_issue := GdvoskExtensionConfig.validate_installed_manifest()
	if not manifest_issue.is_empty():
		push_error(manifest_issue)
		print("Manifest issue: ", manifest_issue)
	var loaded := GdvoskExtensionConfig.is_extension_loaded()
	print("VoskRecognizer available: ", loaded)
	var ok := manifest_issue.is_empty() and loaded
	quit(0 if ok else 1)
