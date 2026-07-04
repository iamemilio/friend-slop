class_name DisplayResolutionPresets
extends RefCounted

## Window resolution presets for the settings dropdown.

const DEFAULT_SIZE := Vector2i(1920, 1080)
const UHD_4K := Vector2i(3840, 2160)

const STANDARD_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	DEFAULT_SIZE,
	Vector2i(2560, 1440),
	UHD_4K,
]

## Back-compat alias for tests and callers that read the static list.
const PRESETS := STANDARD_PRESETS


static func get_default_monitor_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return DEFAULT_SIZE
	var screen_id := DisplayServer.get_primary_screen()
	var logical := DisplayServer.screen_get_size(screen_id)
	if logical.x <= 0 or logical.y <= 0:
		return DEFAULT_SIZE
	var dpi := float(DisplayServer.screen_get_dpi(screen_id))
	if dpi > 96.0:
		var scale := dpi / 96.0
		var estimated := Vector2i(
			roundi(float(logical.x) * scale),
			roundi(float(logical.y) * scale)
		)
		return _snap_to_nearest_standard(estimated)
	return _snap_to_nearest_standard(logical)


static func build_presets(include_size: Vector2i = Vector2i.ZERO) -> Array[Vector2i]:
	var presets: Array[Vector2i] = []
	_add_unique_preset(presets, get_default_monitor_size())
	if include_size.x > 0 and include_size.y > 0:
		_add_unique_preset(presets, include_size)
	for size in STANDARD_PRESETS:
		_add_unique_preset(presets, size)
	return _sort_presets_descending(presets)


static func preset_count() -> int:
	return build_presets().size()


static func get_preset(index: int, include_size: Vector2i = Vector2i.ZERO) -> Vector2i:
	var presets := build_presets(include_size)
	if index < 0 or index >= presets.size():
		return get_default_monitor_size()
	return presets[index]


static func format_label(size: Vector2i) -> String:
	var label := "%d x %d" % [size.x, size.y]
	if size == UHD_4K:
		return label + " (4K)"
	if size == get_default_monitor_size():
		return label + " (Native)"
	return label


static func find_preset_index(size: Vector2i, include_size: Vector2i = Vector2i.ZERO) -> int:
	var presets := build_presets(include_size)
	for i in presets.size():
		if presets[i] == size:
			return i
	return find_default_preset_index(include_size)


static func find_default_preset_index(include_size: Vector2i = Vector2i.ZERO) -> int:
	return find_preset_index(get_default_monitor_size(), include_size)


static func normalize_size(size: Vector2i) -> Vector2i:
	if find_preset_index(size, size) >= 0:
		return size
	return get_default_monitor_size()


static func includes_uhd_4k() -> bool:
	return build_presets().has(UHD_4K)


static func _snap_to_nearest_standard(size: Vector2i) -> Vector2i:
	var best := DEFAULT_SIZE
	var best_distance := INF
	for preset in STANDARD_PRESETS:
		var distance: float = absf(float(preset.x - size.x)) + absf(float(preset.y - size.y))
		if distance < best_distance:
			best_distance = distance
			best = preset
	return best


static func _sort_presets_descending(presets: Array[Vector2i]) -> Array[Vector2i]:
	var sorted := presets.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var area_a := a.x * a.y
		var area_b := b.x * b.y
		if area_a == area_b:
			return a.x > b.x
		return area_a > area_b
	)
	return sorted


static func _add_unique_preset(presets: Array[Vector2i], size: Vector2i) -> void:
	for existing in presets:
		if existing == size:
			return
	presets.append(size)
