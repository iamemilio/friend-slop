class_name TestDisplayResolutionPresets
extends RefCounted

const DisplayResolutionPresetsScript := preload("res://scripts/ui/display_resolution_presets.gd")


func run() -> int:
	if DisplayResolutionPresetsScript.preset_count() < 4:
		push_error("Expected several resolution presets")
		return 1
	if DisplayResolutionPresetsScript.find_preset_index(Vector2i(1920, 1080)) != 3:
		push_error("Expected 1920x1080 preset index")
		return 1
	if DisplayResolutionPresetsScript.format_label(Vector2i(1280, 720)) != "1280 x 720":
		push_error("Expected formatted resolution label")
		return 1
	var normalized := DisplayResolutionPresetsScript.normalize_size(Vector2i(9999, 8888))
	if normalized != DisplayResolutionPresetsScript.DEFAULT_SIZE:
		push_error("Expected unknown resolutions to fall back to default")
		return 1
	return 0
