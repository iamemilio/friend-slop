class_name TestDisplayResolutionPresets
extends RefCounted

const DisplayResolutionPresetsScript := preload("res://scripts/ui/display_resolution_presets.gd")


func run() -> int:
	var failures := 0
	if DisplayResolutionPresetsScript.preset_count() < 4:
		failures += 1
		push_error("Expected several resolution presets")
	var presets := DisplayResolutionPresetsScript.build_presets()
	if not presets.has(Vector2i(1920, 1080)):
		failures += 1
		push_error("Expected 1920x1080 in preset list")
	if not DisplayResolutionPresetsScript.includes_uhd_4k():
		failures += 1
		push_error("Expected 3840x2160 (4K) in preset list")
	if presets.size() > 1 and presets[0].x * presets[0].y < presets[1].x * presets[1].y:
		failures += 1
		push_error("Expected presets sorted largest first")
	if DisplayResolutionPresetsScript.format_label(Vector2i(1280, 720)) != "1280 x 720":
		failures += 1
		push_error("Expected formatted resolution label")
	if DisplayResolutionPresetsScript.format_label(Vector2i(3840, 2160)) != "3840 x 2160 (4K)":
		failures += 1
		push_error("Expected 4K preset label")
	var normalized := DisplayResolutionPresetsScript.normalize_size(Vector2i(9999, 8888))
	if normalized != DisplayResolutionPresetsScript.get_default_monitor_size():
		failures += 1
		push_error("Expected unknown resolutions to fall back to native default")
	return failures
