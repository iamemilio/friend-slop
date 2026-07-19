extends Control

const UiScaleScript := preload("res://scripts/ui/ui_scale.gd")

const TITLE_FONT_BASE := 48
const BUTTON_FONT_BASE := 20
const BUTTON_WIDTH_BASE := 240.0
const BUTTON_HEIGHT_BASE := 48.0
const VBOX_SEPARATION_BASE := 18

@onready var _center_container: CenterContainer = $CenterContainer
@onready var _menu_vbox: VBoxContainer = $CenterContainer/VBoxContainer
@onready var _title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var _play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var _join_button: Button = $CenterContainer/VBoxContainer/JoinButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _lobby_panel: LobbyPanel = $LobbyPanel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_play_button.pressed.connect(_on_play_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	_lobby_panel.closed.connect(_on_lobby_closed)
	get_viewport().size_changed.connect(_apply_menu_layout)
	_apply_menu_layout()


func _apply_menu_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var button_width := UiScaleScript.scaled(BUTTON_WIDTH_BASE, viewport_size, 160.0)
	var button_height := UiScaleScript.scaled(BUTTON_HEIGHT_BASE, viewport_size, 36.0)
	var button_font := UiScaleScript.scaled(float(BUTTON_FONT_BASE), viewport_size, 14.0)
	var title_font := UiScaleScript.scaled(float(TITLE_FONT_BASE), viewport_size, 28.0)
	var separation := UiScaleScript.scaled(float(VBOX_SEPARATION_BASE), viewport_size, 10.0)

	_menu_vbox.add_theme_constant_override("separation", separation)
	_title_label.add_theme_font_size_override("font_size", title_font)

	for button in _menu_buttons():
		button.add_theme_font_size_override("font_size", button_font)
		button.custom_minimum_size = Vector2(button_width, button_height)


func _menu_buttons() -> Array[Button]:
	return [
		_play_button,
		_join_button,
		_settings_button,
		_exit_button,
	]


func _on_play_pressed() -> void:
	_hide_menu()
	_lobby_panel.open_host()


func _on_join_pressed() -> void:
	_hide_menu()
	_lobby_panel.open_join()


func _on_settings_pressed() -> void:
	_hide_menu()
	_settings_panel.open()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_settings_closed() -> void:
	_show_menu()


func _on_lobby_closed() -> void:
	_show_menu()


func _hide_menu() -> void:
	_center_container.visible = false


func _show_menu() -> void:
	_center_container.visible = true
	_apply_menu_layout()
