class_name DisplayResolutionPresets
extends RefCounted

## Known window resolutions for the settings dropdown.

const DEFAULT_SIZE := Vector2i(1920, 1080)

const PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]


static func preset_count() -> int:
	return PRESETS.size()


static func get_preset(index: int) -> Vector2i:
	if index < 0 or index >= PRESETS.size():
		return DEFAULT_SIZE
	return PRESETS[index]


static func format_label(size: Vector2i) -> String:
	return "%d x %d" % [size.x, size.y]


static func find_preset_index(size: Vector2i) -> int:
	for i in PRESETS.size():
		if PRESETS[i] == size:
			return i
	return find_default_preset_index()


static func find_default_preset_index() -> int:
	return find_preset_index(DEFAULT_SIZE)


static func normalize_size(size: Vector2i) -> Vector2i:
	if find_preset_index(size) >= 0:
		return size
	return DEFAULT_SIZE
