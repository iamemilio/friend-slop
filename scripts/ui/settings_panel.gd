class_name SettingsPanel
extends Control

signal closed

const DisplayResolutionPresetsScript := preload("res://scripts/ui/display_resolution_presets.gd")

var _mic_test_active := false
var _mic_peak: float = 0.0
var _output_device_option: OptionButton
var _input_device_option: OptionButton
var _master_volume_slider: HSlider
var _master_volume_label: Label
var _mic_test_button: Button
var _mic_level_bar: ProgressBar
var _mic_status_label: Label
var _resolution_option: OptionButton
var _resolution_hint_label: Label
var _dev_apprentice_button: Button
var _dev_warden_button: Button
var _voice_stub_checkbox: CheckBox
var _dev_spawn_relic_near_spawn_checkbox: CheckBox
var _dev_allow_any_lobby_size_checkbox: CheckBox
var _dev_solo_role: int = GameState.PlayerRole.APPRENTICE

@onready var _general_vbox: VBoxContainer = (
	$Panel/MarginContainer/VBox/TabContainer/General/MarginContainer/GeneralVBox
)
@onready var _audio_vbox: VBoxContainer = (
	$Panel/MarginContainer/VBox/TabContainer/Audio/MarginContainer/AudioVBox
)
@onready var _dev_vbox: VBoxContainer = (
	$Panel/MarginContainer/VBox/TabContainer/Developer/MarginContainer/DevVBox
)
@onready var _close_button: Button = $Panel/MarginContainer/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cache_node_refs()
	_master_volume_slider.min_value = 0.0
	_master_volume_slider.max_value = 1.0
	_master_volume_slider.step = 0.01
	_mic_level_bar.min_value = 0.0
	_mic_level_bar.max_value = 1.0
	_mic_level_bar.value = 0.0
	_close_button.pressed.connect(_on_close_pressed)
	_mic_test_button.pressed.connect(_on_mic_test_pressed)
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	_dev_apprentice_button.pressed.connect(_on_dev_apprentice_pressed)
	_dev_warden_button.pressed.connect(_on_dev_warden_pressed)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_populate_from_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func open() -> void:
	_populate_from_settings()
	visible = true
	_mic_test_active = false
	_mic_peak = 0.0
	_mic_level_bar.value = 0.0
	_mic_status_label.text = "Press Test Microphone to check input."
	_mic_test_button.text = "Test Microphone"


func close_panel() -> void:
	if _mic_test_active:
		_stop_mic_test()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not _mic_test_active:
		return

	var level: float = SettingsManager.poll_mic_level()
	_mic_peak = maxf(_mic_peak * 0.92, level)
	_mic_level_bar.value = _mic_peak
	if _mic_peak > 0.02:
		_mic_status_label.text = "Microphone detected — speak to see levels."
	elif _mic_peak > 0.005:
		_mic_status_label.text = "Quiet input detected — try speaking louder."
	else:
		_mic_status_label.text = "Listening… no input yet. Check device selection."


func _cache_node_refs() -> void:
	_resolution_option = _general_vbox.get_node("ResolutionOption")
	_resolution_hint_label = _general_vbox.get_node("ResolutionHintLabel")
	_output_device_option = _audio_vbox.get_node("OutputDeviceOption")
	_input_device_option = _audio_vbox.get_node("InputDeviceOption")
	_master_volume_slider = _audio_vbox.get_node("MasterVolumeRow/MasterVolumeSlider")
	_master_volume_label = _audio_vbox.get_node("MasterVolumeRow/MasterVolumeLabel")
	_mic_test_button = _audio_vbox.get_node("MicTestButton")
	_mic_level_bar = _audio_vbox.get_node("MicLevelBar")
	_mic_status_label = _audio_vbox.get_node("MicStatusLabel")
	_dev_apprentice_button = _dev_vbox.get_node("DevRoleSection/DevApprenticeButton")
	_dev_warden_button = _dev_vbox.get_node("DevRoleSection/DevWardenButton")
	_voice_stub_checkbox = _dev_vbox.get_node("VoiceStubCheckBox")
	_dev_spawn_relic_near_spawn_checkbox = _dev_vbox.get_node("DevSpawnRelicNearSpawnCheckBox")
	_dev_allow_any_lobby_size_checkbox = _dev_vbox.get_node("DevAllowAnyLobbySizeCheckBox")


func _populate_from_settings() -> void:
	_populate_resolution_options()
	_select_resolution(SettingsManager.get_window_resolution_preset_index())
	_fill_device_option(
		_output_device_option,
		SettingsManager.get_output_devices(),
		"System Default"
	)
	_fill_device_option(
		_input_device_option,
		SettingsManager.get_input_devices(),
		"System Default"
	)
	_select_device(_output_device_option, SettingsManager.output_device)
	_select_device(_input_device_option, SettingsManager.input_device)
	_master_volume_slider.value = SettingsManager.master_volume
	_update_master_volume_label(SettingsManager.master_volume)
	_dev_solo_role = SettingsManager.dev_solo_role
	_refresh_dev_solo_ui()
	_voice_stub_checkbox.button_pressed = SettingsManager.voice_use_stub
	_dev_spawn_relic_near_spawn_checkbox.button_pressed = (
		SettingsManager.dev_spawn_relic_near_spawn
	)
	_dev_allow_any_lobby_size_checkbox.button_pressed = (
		SettingsManager.dev_allow_any_lobby_size
	)


func _populate_resolution_options() -> void:
	_resolution_option.clear()
	for size in SettingsManager.get_resolution_presets():
		_resolution_option.add_item(DisplayResolutionPresetsScript.format_label(size))
	_update_resolution_hint()


func _update_resolution_hint() -> void:
	if _resolution_hint_label == null:
		return
	if SettingsManager.is_running_embedded_in_editor():
		_resolution_hint_label.text = (
			"Resolution applies when running the exported game or with "
			+ "Embed Game On Next Play disabled in the Godot editor."
		)
	else:
		_resolution_hint_label.text = (
			"Changes the game window size. Drag the window edges to resize manually. "
			+ "Fullscreen is exited automatically when applying a preset."
		)


func _select_resolution(index: int) -> void:
	if _resolution_option.item_count == 0:
		return
	_resolution_option.set_block_signals(true)
	_resolution_option.select(clampi(index, 0, _resolution_option.item_count - 1))
	_resolution_option.set_block_signals(false)


func _refresh_dev_solo_ui() -> void:
	var is_apprentice := _dev_solo_role == GameState.PlayerRole.APPRENTICE
	SelectionStyle.style_choice(_dev_apprentice_button, is_apprentice)
	SelectionStyle.style_choice(_dev_warden_button, not is_apprentice)


func _fill_device_option(
	option: OptionButton,
	devices: PackedStringArray,
	default_label: String
) -> void:
	option.clear()
	option.add_item(default_label)
	for device_name in devices:
		option.add_item(device_name)


func _select_device(option: OptionButton, saved_device: String) -> void:
	if saved_device.is_empty():
		option.select(0)
		return
	for i in option.item_count:
		if option.get_item_text(i) == saved_device:
			option.select(i)
			return
	option.select(0)


func _apply_to_manager() -> void:
	SettingsManager.set_window_resolution_preset_index(_resolution_option.selected)
	SettingsManager.master_volume = _master_volume_slider.value
	SettingsManager.output_device = _read_device_selection(_output_device_option)
	SettingsManager.input_device = _read_device_selection(_input_device_option)
	SettingsManager.dev_solo_role = _dev_solo_role
	SettingsManager.voice_use_stub = _voice_stub_checkbox.button_pressed
	SettingsManager.dev_spawn_relic_near_spawn = (
		_dev_spawn_relic_near_spawn_checkbox.button_pressed
	)
	SettingsManager.dev_allow_any_lobby_size = (
		_dev_allow_any_lobby_size_checkbox.button_pressed
	)
	SettingsManager.apply_audio_settings()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()


func _read_device_selection(option: OptionButton) -> String:
	if option.selected <= 0:
		return ""
	return option.get_item_text(option.selected)


func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_window_resolution_preset_index(index)
	SettingsManager.apply_display_settings()


func _on_dev_apprentice_pressed() -> void:
	_dev_solo_role = GameState.PlayerRole.APPRENTICE
	_refresh_dev_solo_ui()


func _on_dev_warden_pressed() -> void:
	_dev_solo_role = GameState.PlayerRole.WARDEN
	_refresh_dev_solo_ui()


func _on_master_volume_changed(value: float) -> void:
	_update_master_volume_label(value)
	SettingsManager.master_volume = value
	SettingsManager.apply_audio_settings()


func _update_master_volume_label(value: float) -> void:
	_master_volume_label.text = "%d%%" % int(round(value * 100.0))


func _on_mic_test_pressed() -> void:
	if _mic_test_active:
		_stop_mic_test()
	else:
		_start_mic_test()


func _start_mic_test() -> void:
	_apply_to_manager()
	_mic_peak = 0.0
	_mic_level_bar.value = 0.0
	SettingsManager.start_mic_test()
	_mic_test_active = true
	_mic_test_button.text = "Stop Microphone Test"
	_mic_status_label.text = "Listening…"


func _stop_mic_test() -> void:
	SettingsManager.stop_mic_test()
	_mic_test_active = false
	_mic_test_button.text = "Test Microphone"
	_mic_status_label.text = "Microphone test stopped."


func _on_close_pressed() -> void:
	_apply_to_manager()
	close_panel()
