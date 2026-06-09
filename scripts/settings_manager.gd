extends Node

## Loads, applies, and persists player settings to user://settings.cfg.

signal settings_applied

const SETTINGS_PATH := "user://settings.cfg"
const MIC_BUS_NAME := "MicCapture"

var start_third_person: bool = false
var master_volume: float = 1.0
var input_device: String = ""
var output_device: String = ""
var dev_solo_role: int = GameState.PlayerRole.APPRENTICE
var dev_solo_starting_node_id: String = ""
var voice_use_stub: bool = false

var _capture_effect: AudioEffectCapture
var _mic_test_player: AudioStreamPlayer
var _mic_testing: bool = false


func _ready() -> void:
	_ensure_mic_bus()
	load_settings()
	apply_audio_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	start_third_person = config.get_value("general", "start_third_person", start_third_person)
	master_volume = config.get_value("audio", "master_volume", master_volume)
	input_device = config.get_value("audio", "input_device", input_device)
	output_device = config.get_value("audio", "output_device", output_device)
	dev_solo_role = int(config.get_value("dev", "dev_solo_role", dev_solo_role))
	dev_solo_starting_node_id = String(
		config.get_value("dev", "dev_solo_starting_node_id", dev_solo_starting_node_id)
	)
	voice_use_stub = config.get_value("dev", "voice_use_stub", voice_use_stub)
	dev_solo_starting_node_id = _normalize_dev_starting_node_id(
		dev_solo_role,
		dev_solo_starting_node_id
	)


func get_dev_solo_binding() -> Binding:
	var binding := Binding.create_for_role(dev_solo_role)
	var tree := binding.get_tree_definition()
	if tree.is_valid_starting_node(dev_solo_starting_node_id):
		binding.starting_node_id = dev_solo_starting_node_id
	return binding


func apply_solo_dev_loadout_to_game_state() -> void:
	GameState.apply_solo_dev_loadout(dev_solo_role, get_dev_solo_binding())


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "start_third_person", start_third_person)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "input_device", input_device)
	config.set_value("audio", "output_device", output_device)
	dev_solo_starting_node_id = _normalize_dev_starting_node_id(
		dev_solo_role,
		dev_solo_starting_node_id
	)
	config.set_value("dev", "dev_solo_role", dev_solo_role)
	config.set_value("dev", "dev_solo_starting_node_id", dev_solo_starting_node_id)
	config.set_value("dev", "voice_use_stub", voice_use_stub)
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


func _normalize_dev_starting_node_id(role: int, node_id: String) -> String:
	var binding := Binding.create_for_role(role)
	var tree := binding.get_tree_definition()
	if tree.is_valid_starting_node(node_id):
		return node_id
	return tree.get_default_starting_node_id()


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
