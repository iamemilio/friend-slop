extends Node

## Session lifecycle for online games. Swap NorayTransport for SteamTransport later.

signal status_changed(message: String)
signal connection_failed(message: String)
signal became_host(room_code: String)
signal joined_host
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal lobby_roster_changed
signal session_ended(reason: String)

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var transport: MultiplayerTransport = NorayTransport.new()
var is_session_active: bool = false

var _transport_ready: bool = false


func _ready() -> void:
	if transport is NorayTransport:
		(transport as NorayTransport).setup(get_tree())
	transport.status_changed.connect(_forward_transport_status)
	_transport_ready = true

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func get_room_code() -> String:
	return transport.get_room_code()


func get_player_index_for_peer(peer_id: int) -> int:
	var index := get_lobby_peer_ids().find(peer_id)
	return index if index >= 0 else 0


static func compute_player_index_for_peers(peer_id: int, connected_peers: Array) -> int:
	var ids: Array[int] = [1]
	for connected_id in connected_peers:
		ids.append(int(connected_id))
	ids.sort()
	return ids.find(peer_id)


static func collect_lobby_peer_ids(unique_peer_id: int, connected_peers: Array) -> Array[int]:
	var ids: Dictionary = {1: true}
	ids[unique_peer_id] = true
	for peer_id in connected_peers:
		ids[int(peer_id)] = true
	var result: Array[int] = []
	for id in ids.keys():
		result.append(int(id))
	result.sort()
	return result


static func format_lobby_player_label(
	peer_id: int,
	local_peer_id: int,
	connected_peers: Array
) -> String:
	var slot := compute_player_index_for_peers(peer_id, connected_peers) + 1
	var label := "Host" if peer_id == 1 else "Player %d" % slot
	if peer_id == local_peer_id:
		return "%s (You)" % label
	return label


func get_lobby_peer_ids() -> Array[int]:
	if not is_online():
		return []
	return collect_lobby_peer_ids(multiplayer.get_unique_id(), multiplayer.get_peers())


func get_lobby_player_label(peer_id: int) -> String:
	return format_lobby_player_label(
		peer_id,
		multiplayer.get_unique_id(),
		multiplayer.get_peers()
	)


func host_session(noray_host: String = NorayTransport.DEFAULT_NORAY_HOST) -> Error:
	if not _transport_ready:
		return ERR_UNCONFIGURED
	disconnect_session()

	var err: Error = await transport.host({
		"noray_host": noray_host,
	})
	if err != OK:
		connection_failed.emit("Hosting failed.")
		return err

	is_session_active = true
	became_host.emit(get_room_code())
	_notify_lobby_roster_changed()
	return OK


func join_session(
	room_code: String,
	noray_host: String = NorayTransport.DEFAULT_NORAY_HOST
) -> Error:
	if not _transport_ready:
		return ERR_UNCONFIGURED
	disconnect_session()

	var err: Error = await transport.join({
		"noray_host": noray_host,
		"room_code": room_code,
	})
	if err != OK:
		connection_failed.emit("Join failed.")
		return err

	is_session_active = true
	joined_host.emit()
	_notify_lobby_roster_changed()
	return OK


func start_game() -> void:
	if not is_host():
		return
	var run_seed := randi()
	_rpc_start_game.rpc(run_seed)


func disconnect_session() -> void:
	is_session_active = false
	transport.disconnect_session()


func spawn_players(
	players_root: Node3D,
	slime_trails: Node3D,
	configure_local_player: Callable
) -> void:
	for child in players_root.get_children():
		child.queue_free()

	if not GameState.is_multiplayer:
		var solo_player: CharacterBody3D = PLAYER_SCENE.instantiate()
		solo_player.name = "Player"
		players_root.add_child(solo_player)
		solo_player.initialize_snail(0, slime_trails)
		configure_local_player.call(solo_player)
		return

	for peer_id in get_lobby_peer_ids():
		spawn_player_for_peer(peer_id, players_root, slime_trails, configure_local_player)


func spawn_player_for_peer(
	peer_id: int,
	players_root: Node3D,
	slime_trails: Node3D,
	configure_local_player: Callable
) -> void:
	if players_root.get_node_or_null(str(peer_id)) != null:
		return

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	players_root.add_child(player)
	player.initialize_snail(get_player_index_for_peer(peer_id), slime_trails)
	if peer_id == multiplayer.get_unique_id():
		configure_local_player.call(player)


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(run_seed: int) -> void:
	GameState.prepare_multiplayer_game(run_seed)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


@rpc("any_peer", "call_remote", "reliable")
func request_spell_cast(spell_id: String, params: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	broadcast_spell_cast(multiplayer.get_remote_sender_id(), spell_id, params)


func broadcast_spell_cast(caster_peer_id: int, spell_id: String, params: Dictionary) -> void:
	if not GameState.is_multiplayer:
		return
	if multiplayer.is_server():
		_execute_spell_cast.rpc(caster_peer_id, spell_id, params)
	else:
		request_spell_cast.rpc_id(1, spell_id, params)


@rpc("authority", "call_local", "reliable")
func _execute_spell_cast(caster_peer_id: int, spell_id: String, params: Dictionary) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("apply_synced_spell_cast"):
		main.apply_synced_spell_cast(caster_peer_id, spell_id, params)


func _forward_transport_status(message: String) -> void:
	status_changed.emit(message)


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	_notify_lobby_roster_changed()


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	_notify_lobby_roster_changed()


func _on_connected_to_server() -> void:
	status_changed.emit("Connected to host.")
	_notify_lobby_roster_changed()


func _on_connection_failed() -> void:
	connection_failed.emit("Connection failed.")


func _on_server_disconnected() -> void:
	is_session_active = false
	session_ended.emit("Host disconnected.")
	status_changed.emit("Host disconnected.")


func _notify_lobby_roster_changed() -> void:
	lobby_roster_changed.emit()
