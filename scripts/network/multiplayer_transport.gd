class_name MultiplayerTransport
extends RefCounted

## Connection backend for multiplayer sessions.
## Implementation: SteamTransport.

signal status_changed(message: String)


func setup(_tree: SceneTree) -> void:
	pass


func host(_options: Dictionary) -> Error:
	var message := "MultiplayerTransport.host() is not implemented."
	push_error(message)
	status_changed.emit(message)
	return ERR_UNAVAILABLE


func join(_options: Dictionary) -> Error:
	var message := "MultiplayerTransport.join() is not implemented."
	push_error(message)
	status_changed.emit(message)
	return ERR_UNAVAILABLE


func disconnect_session() -> void:
	pass


func get_room_code() -> String:
	return ""


func uses_steam() -> bool:
	return false


func invite_to_session() -> void:
	pass


func get_player_display_name(_peer_id: int) -> String:
	return ""
