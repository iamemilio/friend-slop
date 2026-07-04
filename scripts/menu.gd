extends Control

@onready var _center_container: CenterContainer = $CenterContainer
@onready var _bottom_bar: MarginContainer = $BottomBar
@onready var _exit_button: Button = $BottomBar/ExitButton
@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _lobby_panel: LobbyPanel = $LobbyPanel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$CenterContainer/VBoxContainer/StartButton.pressed.connect(_on_solo_pressed)
	$CenterContainer/VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$CenterContainer/VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	$CenterContainer/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	_lobby_panel.closed.connect(_on_lobby_closed)


func _on_solo_pressed() -> void:
	if SpeechSttLoader.is_loading():
		$CenterContainer/VBoxContainer/StartButton.disabled = true
		await SpeechSttLoader.loading_finished
		$CenterContainer/VBoxContainer/StartButton.disabled = false
	GameState.reset_for_new_game()
	SettingsManager.apply_solo_dev_loadout_to_game_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_host_pressed() -> void:
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
	_bottom_bar.visible = false


func _show_menu() -> void:
	_center_container.visible = true
	_bottom_bar.visible = true
