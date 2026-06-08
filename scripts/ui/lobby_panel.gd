class_name LobbyPanel
extends Control

signal closed
signal start_requested

var _host_mode: bool = false
var _busy: bool = false
var _in_lobby: bool = false

@onready var _title_label: Label = $Panel/MarginContainer/VBox/TitleLabel
@onready var _noray_host_row: HBoxContainer = $Panel/MarginContainer/VBox/NorayHostRow
@onready var _noray_host_edit: LineEdit = $Panel/MarginContainer/VBox/NorayHostRow/NorayHostEdit
@onready var _room_code_host_row: HBoxContainer = (
	$Panel/MarginContainer/VBox/RoomCodeHostRow
)
@onready var _room_code_display: LineEdit = (
	$Panel/MarginContainer/VBox/RoomCodeHostRow/RoomCodeDisplay
)
@onready var _copy_room_code_button: Button = (
	$Panel/MarginContainer/VBox/RoomCodeHostRow/CopyRoomCodeButton
)
@onready var _room_code_edit: LineEdit = $Panel/MarginContainer/VBox/RoomCodeEdit
@onready var _players_section: VBoxContainer = $Panel/MarginContainer/VBox/PlayersSection
@onready var _player_list: ItemList = $Panel/MarginContainer/VBox/PlayersSection/PlayerList
@onready var _status_label: Label = $Panel/MarginContainer/VBox/StatusLabel
@onready var _primary_button: Button = $Panel/MarginContainer/VBox/PrimaryButton
@onready var _back_button: Button = $Panel/MarginContainer/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_primary_button.pressed.connect(_on_primary_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_copy_room_code_button.pressed.connect(_on_copy_room_code_pressed)
	NetworkManager.status_changed.connect(_on_network_status)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.became_host.connect(_on_became_host)
	NetworkManager.joined_host.connect(_on_joined_host)
	NetworkManager.lobby_roster_changed.connect(_refresh_player_list)
	NetworkManager.session_ended.connect(_on_session_ended)


func open_host() -> void:
	_reset_panel_state()
	_host_mode = true
	visible = true
	_title_label.text = "Host Game"
	_room_code_host_row.visible = true
	_room_code_edit.visible = false
	_room_code_display.text = ""
	_room_code_display.placeholder_text = "Connecting…"
	_copy_room_code_button.disabled = true
	_noray_host_edit.text = NorayTransport.DEFAULT_NORAY_HOST
	_status_label.text = "Starting host session…"
	_primary_button.text = "Start Game"
	_primary_button.visible = true
	_primary_button.disabled = true
	_back_button.text = "Back"
	_back_button.disabled = false
	_set_busy(true)
	var err := await NetworkManager.host_session(_noray_host_edit.text.strip_edges())
	_set_busy(false)
	if err != OK:
		_status_label.text = "Hosting failed. Check Noray server and try again."
		_primary_button.disabled = true
		return
	_enter_lobby_ui()
	_primary_button.disabled = false


func open_join() -> void:
	_reset_panel_state()
	_host_mode = false
	visible = true
	_title_label.text = "Join Game"
	_room_code_host_row.visible = false
	_room_code_edit.visible = true
	_room_code_edit.text = ""
	_noray_host_edit.text = NorayTransport.DEFAULT_NORAY_HOST
	_status_label.text = "Enter the host's room code."
	_primary_button.text = "Connect"
	_primary_button.visible = true
	_primary_button.disabled = false
	_back_button.text = "Back"
	_back_button.disabled = false


func close_panel() -> void:
	if _busy:
		return
	_leave_to_menu()


func _on_primary_pressed() -> void:
	if _host_mode:
		if not NetworkManager.is_host():
			_status_label.text = "Host session is not ready."
			return
		NetworkManager.start_game()
		start_requested.emit()
		return

	if _busy or _in_lobby:
		return
	var room_code := _room_code_edit.text.strip_edges()
	if room_code.is_empty():
		_status_label.text = "Enter a room code."
		return
	_set_busy(true)
	_status_label.text = "Connecting…"
	var err := await NetworkManager.join_session(
		room_code,
		_noray_host_edit.text.strip_edges()
	)
	_set_busy(false)
	if err != OK:
		_status_label.text = "Could not join. Check the code and try again."
		return
	_enter_lobby_ui()


func _on_back_pressed() -> void:
	close_panel()


func _on_network_status(message: String) -> void:
	if not _in_lobby:
		_status_label.text = message


func _on_connection_failed(message: String) -> void:
	_status_label.text = message
	_set_busy(false)
	if _host_mode:
		_primary_button.disabled = true
	else:
		_primary_button.disabled = false


func _on_became_host(room_code: String) -> void:
	_room_code_display.text = room_code
	_room_code_display.placeholder_text = ""
	_copy_room_code_button.disabled = false
	_room_code_display.grab_focus()
	_room_code_display.select_all()
	_status_label.text = "Share this code with friends, then start when everyone has joined."


func _on_copy_room_code_pressed() -> void:
	var room_code := _room_code_display.text.strip_edges()
	if room_code.is_empty():
		return
	DisplayServer.clipboard_set(room_code)
	_status_label.text = "Room code copied to clipboard."


func _on_joined_host() -> void:
	if _in_lobby:
		_refresh_player_list()


func _on_session_ended(reason: String) -> void:
	if not visible or _host_mode:
		return
	_status_label.text = reason
	_leave_to_menu()


func _enter_lobby_ui() -> void:
	_in_lobby = true
	_noray_host_row.visible = false
	_room_code_edit.visible = false
	_players_section.visible = true
	if _host_mode:
		_room_code_host_row.visible = true
		_primary_button.visible = true
		_primary_button.disabled = false
		_back_button.text = "Back"
		_status_label.text = "Share the room code, then start when everyone has joined."
	else:
		_room_code_host_row.visible = false
		_primary_button.visible = false
		_back_button.text = "Leave"
		_status_label.text = "Waiting for the host to start…"
	_refresh_player_list()


func _refresh_player_list() -> void:
	if not _in_lobby or not NetworkManager.is_online():
		return
	_player_list.clear()
	for peer_id in NetworkManager.get_lobby_peer_ids():
		_player_list.add_item(NetworkManager.get_lobby_player_label(peer_id))


func _leave_to_menu() -> void:
	_in_lobby = false
	NetworkManager.disconnect_session()
	visible = false
	_reset_panel_state()
	closed.emit()


func _reset_panel_state() -> void:
	_in_lobby = false
	_players_section.visible = false
	_player_list.clear()
	_noray_host_row.visible = true
	_room_code_host_row.visible = true
	_room_code_edit.visible = false
	_primary_button.visible = true
	_back_button.text = "Back"


func _set_busy(busy: bool) -> void:
	_busy = busy
	_back_button.disabled = busy
	if not _host_mode and not _in_lobby:
		_primary_button.disabled = busy
