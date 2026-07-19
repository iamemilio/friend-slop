class_name PauseMenu
extends CanvasLayer

signal quit_to_menu_requested

var _paused := false
var _spellbook_was_open := false

@onready var _menu_panel: Control = $MenuPanel
@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _resume_button: Button = $MenuPanel/CenterContainer/VBox/ResumeButton
@onready var _settings_button: Button = $MenuPanel/CenterContainer/VBox/SettingsButton
@onready var _end_game_button: Button = $MenuPanel/CenterContainer/VBox/EndGameButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_menu_panel.visible = true
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_end_game_button.pressed.connect(_on_end_game_pressed)
	_settings_panel.closed.connect(_on_settings_closed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.is_open():
		_settings_panel.close_panel()
		return
	if _paused:
		resume()
	else:
		pause()


func is_paused() -> bool:
	return _paused


func pause() -> void:
	if _paused:
		return
	_paused = true
	visible = true
	_menu_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_spellbook_was_open = _is_spellbook_open()
	if _spellbook_was_open:
		_close_spellbook()
	_cancel_casting()


func resume() -> void:
	if not _paused:
		return
	if _settings_panel.is_open():
		_settings_panel.close_panel()
	_paused = false
	visible = false
	get_tree().paused = false
	if _spellbook_was_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	resume()


func _on_settings_pressed() -> void:
	_menu_panel.visible = false
	_settings_panel.open()


func _on_settings_closed() -> void:
	if _paused:
		_menu_panel.visible = true


func _on_end_game_pressed() -> void:
	if _settings_panel.is_open():
		_settings_panel.close_panel()
	get_tree().paused = false
	_paused = false
	visible = false
	quit_to_menu_requested.emit()


func _cancel_casting() -> void:
	var session: Node = get_tree().get_first_node_in_group("casting_session")
	if session != null and session.has_method("cancel"):
		session.cancel()


func _is_spellbook_open() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("is_spellbook_open"):
		return hud.is_spellbook_open()
	return false


func _close_spellbook() -> void:
	var hud: Node = get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("close_spellbook"):
		hud.close_spellbook()
