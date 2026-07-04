extends Node

## Loads, applies, and persists player settings to user://settings.cfg.

signal settings_applied

const DisplayResolutionPresetsScript := preload("res://scripts/ui/display_resolution_presets.gd")

const SETTINGS_PATH := "user://settings.cfg"
const MIC_BUS_NAME := "MicCapture"

var start_third_person: bool = false
var window_width: int = 0
var window_height: int = 0
var master_volume: float = 1.0
var input_device: String = ""
var output_device: String = ""
var dev_solo_role: int = GameState.PlayerRole.APPRENTICE
var voice_use_stub: bool = false
var dev_spawn_relic_near_spawn: bool = false
var dev_allow_any_lobby_size: bool = false

var _capture_effect: AudioEffectCapture
var _mic_test_player: AudioStreamPlayer
var _mic_testing: bool = false


func _ready() -> void:
	_ensure_mic_bus()
	load_settings()
	apply_audio_settings()
	apply_display_settings()


func get_resolution_presets() -> Array[Vector2i]:
	return DisplayResolutionPresetsScript.build_presets(Vector2i(window_width, window_height))


func set_window_resolution(width: int, height: int) -> void:
	var size := DisplayResolutionPresetsScript.normalize_size(Vector2i(width, height))
	window_width = size.x
	window_height = size.y


func set_window_resolution_preset_index(index: int) -> void:
	var current := Vector2i(window_width, window_height)
	var size := DisplayResolutionPresetsScript.get_preset(index, current)
	window_width = size.x
	window_height = size.y


func get_window_resolution_preset_index() -> int:
	var current := Vector2i(window_width, window_height)
	return DisplayResolutionPresetsScript.find_preset_index(current, current)


func is_running_embedded_in_editor() -> bool:
	return Engine.is_embedded_in_editor()


func apply_display_settings() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if Engine.is_embedded_in_editor():
		return
	call_deferred("_deferred_apply_window_size", Vector2i(window_width, window_height))


func _deferred_apply_window_size(target: Vector2i) -> void:
	if Engine.is_embedded_in_editor():
		return
	var window := get_tree().root as Window
	if window == null:
		return
	_ensure_windowed(window)
	_configure_root_window(window)
	window.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(target)
	window.size = target
	DisplayServer.window_set_min_size(Vector2i(640, 360))
	_center_window(target)


func _configure_root_window(window: Window) -> void:
	window.borderless = false
	window.unresizable = false
	window.popup_window = false
	window.extend_to_title = false
	window.exclusive = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_EXTEND_TO_TITLE, false)


func _center_window(size: Vector2i) -> void:
	var screen_id := DisplayServer.window_get_current_screen()
	if screen_id < 0:
		screen_id = DisplayServer.get_primary_screen()
	var screen_origin := DisplayServer.screen_get_position(screen_id)
	var screen_size := DisplayServer.screen_get_size(screen_id)
	var window_pos := screen_origin + (screen_size - size) / 2
	DisplayServer.window_set_position(window_pos)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_native_default_window_size()
		return

	start_third_person = config.get_value("general", "start_third_person", start_third_person)
	window_width = int(config.get_value("display", "window_width", window_width))
	window_height = int(config.get_value("display", "window_height", window_height))
	if window_width <= 0 or window_height <= 0:
		_apply_native_default_window_size()
		return
	var normalized := DisplayResolutionPresetsScript.normalize_size(
		Vector2i(window_width, window_height)
	)
	window_width = normalized.x
	window_height = normalized.y
	master_volume = config.get_value("audio", "master_volume", master_volume)
	input_device = config.get_value("audio", "input_device", input_device)
	output_device = config.get_value("audio", "output_device", output_device)
	dev_solo_role = int(config.get_value("dev", "dev_solo_role", dev_solo_role))
	voice_use_stub = config.get_value("dev", "voice_use_stub", voice_use_stub)
	dev_spawn_relic_near_spawn = config.get_value(
		"dev", "dev_spawn_relic_near_spawn", dev_spawn_relic_near_spawn
	)
	dev_allow_any_lobby_size = config.get_value(
		"dev", "dev_allow_any_lobby_size", dev_allow_any_lobby_size
	)


func apply_solo_dev_loadout_to_game_state() -> void:
	GameState.apply_solo_dev_loadout(dev_solo_role)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "start_third_person", start_third_person)
	config.set_value("display", "window_width", window_width)
	config.set_value("display", "window_height", window_height)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "input_device", input_device)
	config.set_value("audio", "output_device", output_device)
	config.set_value("dev", "dev_solo_role", dev_solo_role)
	config.set_value("dev", "voice_use_stub", voice_use_stub)
	config.set_value("dev", "dev_spawn_relic_near_spawn", dev_spawn_relic_near_spawn)
	config.set_value("dev", "dev_allow_any_lobby_size", dev_allow_any_lobby_size)
	config.save(SETTINGS_PATH)
	settings_applied.emit()


func apply_audio_settings() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var volume: float = clampf(master_volume, 0.0, 1.0)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(volume, 0.0001)))

	if not output_device.is_empty():
		AudioServer.set_output_device(output_device)
	if not input_device.is_empty():
		AudioServer.set_input_device(input_device)


func get_input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()


func get_capture_effect() -> AudioEffectCapture:
	return _capture_effect


func is_mic_testing() -> bool:
	return _mic_testing


func start_mic_test() -> void:
	stop_mic_test()
	if _capture_effect:
		_capture_effect.clear_buffer()

	_mic_test_player = AudioStreamPlayer.new()
	_mic_test_player.name = "MicTest"
	_mic_test_player.bus = MIC_BUS_NAME
	_mic_test_player.stream = AudioStreamMicrophone.new()
	add_child(_mic_test_player)
	_mic_test_player.play()
	_mic_testing = true


func stop_mic_test() -> void:
	_mic_testing = false
	if _mic_test_player != null:
		if _mic_test_player.playing:
			_mic_test_player.stop()
		_mic_test_player.queue_free()
		_mic_test_player = null
	if _capture_effect:
		_capture_effect.clear_buffer()


func poll_mic_level() -> float:
	if _capture_effect == null or not _mic_testing:
		return 0.0

	var sum_sq: float = 0.0
	var count: int = 0
	while _capture_effect.can_get_buffer(256):
		var chunk: PackedVector2Array = _capture_effect.get_buffer(256)
		for frame in chunk:
			var sample: float = (frame.x + frame.y) * 0.5
			sum_sq += sample * sample
			count += 1

	if count == 0:
		return 0.0
	return sqrt(sum_sq / float(count))


func _ensure_mic_bus() -> void:
	if AudioServer.get_bus_index(MIC_BUS_NAME) >= 0:
		_cache_capture_effect()
		return

	AudioServer.add_bus()
	var bus_idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_idx, MIC_BUS_NAME)
	AudioServer.set_bus_mute(bus_idx, true)
	AudioServer.add_bus_effect(bus_idx, AudioEffectCapture.new())
	_cache_capture_effect()


func _cache_capture_effect() -> void:
	var bus_idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if bus_idx < 0:
		return
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectCapture:
			_capture_effect = effect
			return


func _ensure_windowed(window: Window) -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		window.mode = Window.MODE_WINDOWED


func _apply_native_default_window_size() -> void:
	var native := DisplayResolutionPresetsScript.get_default_monitor_size()
	window_width = native.x
	window_height = native.y
