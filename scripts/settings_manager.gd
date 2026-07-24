extends Node

## Loads, applies, and persists player settings to user://settings.cfg.

signal settings_applied

const DisplayResolutionPresetsScript := preload("res://scripts/ui/display_resolution_presets.gd")
const MicCaptureBrokerScript := preload("res://scripts/voice/mic_capture_broker.gd")

const SETTINGS_PATH := "user://settings.cfg"
const MIC_BUS_NAME := "MicCapture"
const CAPTURE_DEVICE_RETRY_MAX := 20
const CAPTURE_DEVICE_RETRY_SEC := 0.25

var window_width: int = DisplayResolutionPresetsScript.DEFAULT_SIZE.x
var window_height: int = DisplayResolutionPresetsScript.DEFAULT_SIZE.y
var master_volume: float = 1.0
var mic_volume: float = 1.0
var mic_muted: bool = false
var input_device: String = ""
var output_device: String = ""
## Hear local mic through speakers during voice chat (and mic test).
var hear_myself: bool = false
var dev_solo_role: int = GameState.PlayerRole.APPRENTICE
var voice_use_stub: bool = false
var lobby_voice_default: bool = true
var dev_spawn_relic_near_spawn: bool = false
var dev_allow_any_lobby_size: bool = false

var _mic_testing: bool = false
var _voice_meter_active: bool = false
## Last input_device preference string (UI), and last WASAPI device we opened.
var _applied_input_device: String = ""
var _opened_capture_device: String = ""
var _capture_device_retry_count: int = 0
var _capture_device_retry_scheduled: bool = false


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
	## Avoid popup_window / WINDOW_FLAG_POPUP — setting either on the main window errors.
	window.extend_to_title = false
	window.exclusive = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_EXTEND_TO_TITLE, false)


func _center_window(window_size: Vector2i) -> void:
	var screen_id := DisplayServer.window_get_current_screen()
	if screen_id < 0:
		screen_id = DisplayServer.get_primary_screen()
	var screen_origin := DisplayServer.screen_get_position(screen_id)
	var screen_size := DisplayServer.screen_get_size(screen_id)
	var delta := screen_size - window_size
	var window_pos := screen_origin + Vector2i(int(delta.x * 0.5), int(delta.y * 0.5))
	DisplayServer.window_set_position(window_pos)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_native_default_window_size()
		return

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
	mic_volume = float(config.get_value("audio", "mic_volume", mic_volume))
	mic_muted = bool(config.get_value("audio", "mic_muted", mic_muted))
	input_device = config.get_value("audio", "input_device", input_device)
	output_device = config.get_value("audio", "output_device", output_device)
	lobby_voice_default = bool(
		config.get_value("audio", "lobby_voice_default", lobby_voice_default)
	)
	## Prefer hear_myself; fall back to short-lived mic_test_monitor key if present.
	if config.has_section_key("audio", "hear_myself"):
		hear_myself = bool(config.get_value("audio", "hear_myself", hear_myself))
	elif config.has_section_key("audio", "mic_test_monitor"):
		hear_myself = bool(config.get_value("audio", "mic_test_monitor", hear_myself))
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
	config.set_value("display", "window_width", window_width)
	config.set_value("display", "window_height", window_height)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "mic_volume", mic_volume)
	config.set_value("audio", "mic_muted", mic_muted)
	config.set_value("audio", "input_device", input_device)
	config.set_value("audio", "output_device", output_device)
	config.set_value("audio", "lobby_voice_default", lobby_voice_default)
	config.set_value("audio", "hear_myself", hear_myself)
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

	## MicCapture must stay at 0 dB so STT sees full-scale PCM. Apply mic_volume
	## only as software gain on the VoIP encode path and UI meters.
	_ensure_mic_bus()
	var mic_idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if mic_idx >= 0:
		AudioServer.set_bus_volume_db(mic_idx, 0.0)
	_set_broker_output_monitor(hear_myself)

	if not output_device.is_empty():
		AudioServer.set_output_device(output_device)

	var previous_capture := _opened_capture_device
	var capture_device := _resolve_capture_input_device()
	if (
		capture_device.is_empty()
		and not input_device.is_empty()
		and input_device != "Default"
	):
		## Boot often enumerates only ["Default"] before real WASAPI names appear.
		## Do not substitute another device — retry until the saved name shows up.
		_schedule_capture_device_retry()
		_applied_input_device = input_device
		return
	_capture_device_retry_count = 0
	if not capture_device.is_empty():
		AudioServer.set_input_device(capture_device)
		_opened_capture_device = capture_device
	_applied_input_device = input_device
	if previous_capture == _opened_capture_device:
		return
	var broker := _find_mic_broker()
	if (
		broker != null
		and broker.has_method("rebind_mic_stream")
		and int(broker.call("get_subscriber_count")) > 0
	):
		broker.call("rebind_mic_stream")


func _schedule_capture_device_retry() -> void:
	if _capture_device_retry_scheduled:
		return
	if _capture_device_retry_count >= CAPTURE_DEVICE_RETRY_MAX:
		push_warning(
			"SettingsManager: saved input '%s' not in device list after retries"
			% input_device
		)
		return
	_capture_device_retry_scheduled = true
	_capture_device_retry_count += 1
	var tree := get_tree()
	if tree == null:
		_capture_device_retry_scheduled = false
		return
	tree.create_timer(CAPTURE_DEVICE_RETRY_SEC).timeout.connect(
		_on_capture_device_retry_timeout
	)


func _on_capture_device_retry_timeout() -> void:
	_capture_device_retry_scheduled = false
	var capture_device := _resolve_capture_input_device()
	if capture_device.is_empty():
		_schedule_capture_device_retry()
		return
	apply_audio_settings()


## Honor the Settings input device exactly.
## Empty / "Default" = System Default. Never remap HyperX→Default or auto-pick
## another mic — that ignored the user's designated device (debug 2c05d7 H).
func _resolve_capture_input_device() -> String:
	var devices := AudioServer.get_input_device_list()
	if input_device.is_empty() or input_device == "Default":
		if _device_list_has(devices, "Default"):
			return "Default"
		return ""
	if _device_list_has(devices, input_device):
		return input_device
	return ""


func _device_list_has(devices: PackedStringArray, needle: String) -> bool:
	for device_name in devices:
		if device_name == needle:
			return true
	return false


func get_input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()


func is_mic_testing() -> bool:
	return _mic_testing


func start_mic_test() -> void:
	## Ensure the saved device is selected before opening the shared broker mic.
	apply_audio_settings()
	_mic_testing = true
	if not _subscribe_meter():
		_mic_testing = false
		push_error("SettingsManager: mic test failed — MicCaptureBroker unavailable")
		return
	## If still silent after a beat, dump stage diagnosis to the console.
	var broker := _find_mic_broker()
	if broker != null and broker.has_method("diagnose_capture"):
		get_tree().create_timer(0.85).timeout.connect(
			func() -> void:
				if _mic_testing and broker.has_method("diagnose_capture"):
					broker.call("diagnose_capture")
		)


func stop_mic_test() -> void:
	_mic_testing = false
	_maybe_unsubscribe_meter()


## Silent meter for lobby/game speaking indicators (same capture path as mic test).
func start_voice_meter() -> void:
	_voice_meter_active = true
	if not _subscribe_meter():
		_voice_meter_active = false


func stop_voice_meter() -> void:
	_voice_meter_active = false
	_maybe_unsubscribe_meter()


## Drop settings-only meter subscription before VoiceSession takes the broker.
func release_microphone_for_voice() -> void:
	_mic_testing = false
	_voice_meter_active = false
	_unsubscribe_meter()


## Clear a stored input device that opened a silent WASAPI endpoint.
func clear_input_device_preference() -> void:
	input_device = ""
	_applied_input_device = ""
	_opened_capture_device = ""


func poll_mic_level() -> float:
	var broker := _find_mic_broker()
	if broker == null:
		return 0.0
	if not bool(broker.call("is_capturing")):
		return 0.0
	## Same PCM path as Match voice/STT — slider only scales the UI meter.
	return float(broker.call("get_last_rms")) * clampf(mic_volume, 0.0, 1.0)


func _subscribe_meter() -> bool:
	var broker := _find_mic_broker()
	if broker == null or not broker.has_method("subscribe"):
		return false
	## No-op sink: keeps capture alive so get_last_rms updates. Chat/spellcasting
	## may already be subscribed; replacing meter is fine.
	return bool(
		broker.call(
			"subscribe",
			MicCaptureBrokerScript.SUB_METER,
			Callable(self, "_on_meter_pcm")
		)
	)


func _unsubscribe_meter() -> void:
	var broker := _find_mic_broker()
	if broker != null and broker.has_method("unsubscribe"):
		broker.call("unsubscribe", MicCaptureBrokerScript.SUB_METER)


func _maybe_unsubscribe_meter() -> void:
	if _mic_testing or _voice_meter_active:
		return
	_unsubscribe_meter()


func _on_meter_pcm(_mono: PackedFloat32Array, _mix_rate: int) -> void:
	## Intentionally empty — MicCaptureBroker updates get_last_rms while draining.
	pass


func _find_mic_broker() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("mic_capture_broker")


func _set_broker_output_monitor(enabled: bool) -> void:
	var broker := _find_mic_broker()
	if broker != null and broker.has_method("set_output_monitor"):
		broker.call("set_output_monitor", enabled)


func _ensure_mic_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if bus_idx < 0:
		AudioServer.add_bus()
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, MIC_BUS_NAME)
		AudioServer.add_bus_effect(bus_idx, AudioEffectCapture.new())
	## Prefer broker config (owns MicCapture mute + hear-myself sidetone).
	var broker := _find_mic_broker()
	if broker != null and broker.has_method("ensure_mic_bus_configured"):
		broker.call("ensure_mic_bus_configured")
		return
	## Early boot before broker exists: mute MicCapture (capture still works).
	AudioServer.set_bus_mute(bus_idx, true)
	AudioServer.set_bus_volume_db(bus_idx, 0.0)
	AudioServer.set_bus_send(bus_idx, &"")


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
