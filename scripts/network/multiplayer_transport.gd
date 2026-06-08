class_name MultiplayerTransport
extends RefCounted

## Connection backend for multiplayer sessions.
## Implementations: NorayTransport now, SteamTransport later.

signal status_changed(message: String)


func host(_options: Dictionary) -> Error:
	push_error("MultiplayerTransport.host() is not implemented.")
	return ERR_UNAVAILABLE


func join(_options: Dictionary) -> Error:
	push_error("MultiplayerTransport.join() is not implemented.")
	return ERR_UNAVAILABLE


func disconnect_session() -> void:
	pass


func get_room_code() -> String:
	return ""
