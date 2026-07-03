extends Node

## Session lifecycle for online games. Transport: Steam P2P.

signal status_changed(message: String)
signal connection_failed(message: String)
signal became_host(room_code: String)
signal joined_host
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal lobby_roster_changed
signal lobby_roles_changed
signal lobby_character_configs_changed
signal session_ended(reason: String)
signal steam_lobby_invite_received(lobby_id: int)

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DEFAULT_HORROR_CONFIG := preload("res://resources/match/default_horror_config.tres")

const SteamTransportScript := preload("res://scripts/network/steam_transport.gd")

var transport: MultiplayerTransport
var is_session_active: bool = false
var lobby: LobbyMatchState = LobbyMatchState.new()

var _transport_ready: bool = false


func _ready() -> void:
	_configure_transport()
	transport.status_changed.connect(_forward_transport_status)
	_transport_ready = true

	if SteamService.lobby_invite_received.is_connected(_on_steam_lobby_invite_received):
		SteamService.lobby_invite_received.disconnect(_on_steam_lobby_invite_received)
	SteamService.lobby_invite_received.connect(_on_steam_lobby_invite_received)
	SteamService.lobby_member_joined.connect(_on_steam_lobby_member_joined)
	became_host.connect(_on_became_host_sync_steam_peers)

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
	var steam_name := transport.get_player_display_name(peer_id)
	var suffix := " (You)" if peer_id == multiplayer.get_unique_id() else ""
	var label := ""
	if not steam_name.is_empty():
		if peer_id == 1:
			label = "Host — %s%s" % [steam_name, suffix]
		else:
			label = "%s%s" % [steam_name, suffix]
	else:
		label = format_lobby_player_label(
			peer_id,
			multiplayer.get_unique_id(),
			multiplayer.get_peers()
		)
	return label


func request_lobby_role(role: int) -> void:
	if not is_online():
		return
	if is_host():
		_apply_lobby_role(multiplayer.get_unique_id(), role)
	else:
		_request_lobby_role.rpc_id(1, role)


func request_character_config(config_data: Dictionary) -> void:
	if not is_online():
		return
	if is_host():
		_apply_character_config(multiplayer.get_unique_id(), config_data)
	else:
		_request_character_config.rpc_id(1, config_data)


func host_session(options: Dictionary = {}) -> Error:
	if not _transport_ready:
		return ERR_UNCONFIGURED
	disconnect_session()

	var err: Error = await transport.host(options)
	if err != OK:
		connection_failed.emit("Hosting failed.")
		return err

	is_session_active = true
	lobby.reset()
	lobby.set_default_roles([1])
	_broadcast_lobby_state()
	became_host.emit(get_room_code())
	_notify_lobby_roster_changed()
	return OK


func join_session(room_code: String, options: Dictionary = {}) -> Error:
	if not _transport_ready:
		return ERR_UNCONFIGURED
	disconnect_session()

	var join_options := options.duplicate()
	join_options["room_code"] = room_code

	var err: Error = await transport.join(join_options)
	if err != OK:
		connection_failed.emit("Join failed.")
		return err

	is_session_active = true
	joined_host.emit()
	_notify_lobby_roster_changed()
	return OK


func invite_friends() -> void:
	transport.invite_to_session()


func start_game() -> void:
	if not is_host():
		return
	_sync_steam_lobby_peers()
	_ensure_lobby_roles_for_peers()
	var peer_ids := get_lobby_peer_ids()
	if not lobby.can_start(peer_ids):
		status_changed.emit(lobby.get_start_block_reason(peer_ids))
		return
	var run_seed := randi()
	var roles_payload := _pack_roles_for_current_peers()
	var configs_payload := _pack_character_configs_for_current_peers()
	var match_snapshot := MatchStateSnapshot.pack_initial(DEFAULT_HORROR_CONFIG)
	TomeDebug.log(
		"NetworkManager",
		"Starting game seed=%s roles=%s configs=%s remote_peers=%s"
		% [run_seed, roles_payload, configs_payload, multiplayer.get_peers()]
	)
	_rpc_start_game.rpc(run_seed, roles_payload, configs_payload, match_snapshot)


func disconnect_session() -> void:
	is_session_active = false
	lobby.reset()
	MatchStateManager.reset()
	TrailRegistry.reset()
	if transport != null:
		transport.disconnect_session()


func spawn_players(
	players_root: Node3D,
	configure_local_player: Callable
) -> void:
	for child in players_root.get_children():
		child.queue_free()

	if not GameState.is_multiplayer:
		var solo_player: CharacterBody3D = PLAYER_SCENE.instantiate()
		solo_player.name = "Player"
		players_root.add_child(solo_player)
		solo_player.initialize_player(0)
		configure_local_player.call(solo_player)
		return

	for peer_id in get_lobby_peer_ids():
		spawn_player_for_peer(peer_id, players_root, configure_local_player)


func spawn_player_for_peer(
	peer_id: int,
	players_root: Node3D,
	configure_local_player: Callable
) -> void:
	if players_root.get_node_or_null(str(peer_id)) != null:
		return

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	players_root.add_child(player)
	player.initialize_player(get_player_index_for_peer(peer_id))
	if peer_id == multiplayer.get_unique_id():
		configure_local_player.call(player)


@rpc("authority", "call_local", "reliable")
func _rpc_start_game(
	run_seed: int,
	roles: Dictionary,
	character_configs: Dictionary,
	match_snapshot: Dictionary
) -> void:
	TomeDebug.log(
		"NetworkManager",
		"Start game RPC received (peer_id=%s, seed=%s)"
		% [multiplayer.get_unique_id(), run_seed]
	)
	MatchStateManager.reset()
	GameState.prepare_match(run_seed, roles, character_configs)
	if not match_snapshot.is_empty():
		MatchStateManager.apply_snapshot(match_snapshot)
	MatchStateManager.log_summary()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func sync_match_phase(next: int) -> void:
	if not is_host():
		return
	var snapshot := MatchStateManager.snapshot
	if snapshot.is_empty():
		return
	var state := MatchState.from_snapshot(snapshot)
	if state.transition_to(next as MatchState.Phase) != OK:
		return
	_rpc_sync_match_snapshot.rpc(MatchStateSnapshot.pack(state))


@rpc("authority", "call_local", "reliable")
func _rpc_sync_match_snapshot(data: Dictionary) -> void:
	MatchStateManager.apply_snapshot(data)


@rpc("authority", "call_local", "reliable")
func _sync_lobby_roles(roles: Dictionary) -> void:
	lobby.roles = LobbyMatchState.normalize_roles(roles)
	lobby_roles_changed.emit()


@rpc("authority", "call_local", "reliable")
func _sync_lobby_character_configs(configs: Dictionary) -> void:
	lobby.character_configs = LobbyMatchState.normalize_character_configs(configs)
	lobby_character_configs_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _request_lobby_role(role: int) -> void:
	if not multiplayer.is_server():
		return
	_apply_lobby_role(multiplayer.get_remote_sender_id(), role)


@rpc("any_peer", "call_remote", "reliable")
func _request_character_config(config_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_apply_character_config(multiplayer.get_remote_sender_id(), config_data)


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


@rpc("any_peer", "call_remote", "unreliable")
func submit_trail_sample(seq: int, x: float, z: float) -> void:
	if not multiplayer.is_server():
		return
	TrailRegistry.host_accept_sample(multiplayer.get_remote_sender_id(), seq, x, z)


@rpc("authority", "call_local", "unreliable")
func broadcast_trail_sample(peer_id: int, seq: int, x: float, z: float, time_msec: int) -> void:
	TrailRegistry.client_apply_sample(peer_id, seq, x, z, time_msec)


func _configure_transport() -> void:
	if not SteamService.is_api_available():
		TomeDebug.log(
			"NetworkManager",
			"GodotSteam unavailable — online play requires the GodotSteam editor or GDExtension."
		)
	transport = SteamTransportScript.new()
	transport.setup(get_tree())


func _forward_transport_status(message: String) -> void:
	status_changed.emit(message)


func _on_steam_lobby_invite_received(lobby_id: int) -> void:
	steam_lobby_invite_received.emit(lobby_id)


func _on_became_host_sync_steam_peers(_room_code: String) -> void:
	call_deferred("_sync_steam_lobby_peers")


func _on_steam_lobby_member_joined(steam_id: int) -> void:
	if not is_host():
		return
	if steam_id == SteamService.get_steam_id():
		return
	_try_add_steam_peer(steam_id)


func _sync_steam_lobby_peers() -> void:
	if not is_host():
		return
	var lobby_id := SteamService.current_lobby_id
	if lobby_id == 0:
		return
	var count := SteamService.get_lobby_member_count(lobby_id)
	for index in range(count):
		var member_id := SteamService.get_lobby_member_by_index(index, lobby_id)
		if member_id == 0 or member_id == SteamService.get_steam_id():
			continue
		_try_add_steam_peer(member_id)


func _try_add_steam_peer(steam_id: int) -> void:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null or not mp_peer.has_method("add_peer"):
		TomeDebug.log("NetworkManager", "Cannot add Steam peer %s — multiplayer peer missing" % steam_id)
		return
	if _steam_peer_already_connected(mp_peer, steam_id):
		return
	var err: Error = mp_peer.call("add_peer", steam_id, 0)
	TomeDebug.log("NetworkManager", "add_peer steam_id=%s err=%s" % [steam_id, err])


func _steam_peer_already_connected(mp_peer: Object, steam_id: int) -> bool:
	if not mp_peer.has_method("get_steam_id_for_peer_id"):
		return false
	for peer_id in multiplayer.get_peers():
		if int(mp_peer.call("get_steam_id_for_peer_id", peer_id)) == steam_id:
			return true
	return false


func _on_peer_connected(peer_id: int) -> void:
	if is_host():
		_ensure_lobby_roles_for_peers()
	peer_connected.emit(peer_id)
	_notify_lobby_roster_changed()


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host() and lobby.remove_peer(peer_id):
		_broadcast_lobby_state()
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
	if is_host():
		_ensure_lobby_roles_for_peers()
	lobby_roster_changed.emit()


func _ensure_lobby_roles_for_peers() -> void:
	if not is_host():
		return
	if lobby.ensure_roles_for_peers(get_lobby_peer_ids()):
		_broadcast_lobby_state()


func _apply_lobby_role(peer_id: int, role: int) -> void:
	lobby.apply_role(peer_id, role)
	_broadcast_lobby_state()


func _apply_character_config(peer_id: int, config_data: Dictionary) -> void:
	lobby.apply_character_config(peer_id, config_data)
	_broadcast_lobby_state()


func _broadcast_lobby_state() -> void:
	_sync_lobby_roles.rpc(lobby.roles.duplicate(true))
	_sync_lobby_character_configs.rpc(lobby.character_configs.duplicate(true))


func _pack_roles_for_current_peers() -> Dictionary:
	return LobbyMatchState.pack_roles_for_peers(lobby.roles, get_lobby_peer_ids())


func _pack_character_configs_for_current_peers() -> Dictionary:
	return LobbyMatchState.pack_character_configs_for_peers(
		lobby.character_configs,
		get_lobby_peer_ids()
	)
