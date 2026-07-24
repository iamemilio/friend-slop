extends Node

## Friend Slop voice: product modes OFF / LOBBY / GAME over library VoiceRuntime nodes.
## Deprovision is always set_mode(OFF) — the hub is an autoload and survives scene changes.

enum Mode { OFF, LOBBY, GAME }

const SteamMultiplayerPeerAdapterScript := preload(
	"res://addons/godot-steam-voice/adapters/steam_multiplayer_peer_adapter.gd"
)

var mode: Mode = Mode.OFF
var lobby_runtime: VoiceRuntime
var game_runtime: VoiceRuntime


func _ready() -> void:
	_build_runtimes()
	if NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_peer_connected)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	if NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	if SteamService.lobby_member_joined.is_connected(_on_steam_lobby_member_joined):
		SteamService.lobby_member_joined.disconnect(_on_steam_lobby_member_joined)
	SteamService.lobby_member_joined.connect(_on_steam_lobby_member_joined)


func get_session() -> VoiceSession:
	if game_runtime != null and game_runtime.is_active():
		return game_runtime.get_session()
	if lobby_runtime != null and lobby_runtime.is_active():
		return lobby_runtime.get_session()
	if lobby_runtime != null:
		return lobby_runtime.get_session()
	if game_runtime != null:
		return game_runtime.get_session()
	return null


func get_mode() -> Mode:
	return mode


func is_active() -> bool:
	return mode != Mode.OFF and _active_runtime() != null and _active_runtime().is_active()


func is_lobby_voice_active() -> bool:
	return mode == Mode.LOBBY and is_active()


## Alias for lifecycle callers (disconnect / quit). Always deprovisions.
func stop_session() -> void:
	set_mode(Mode.OFF)


## Only lifecycle entry point. Leaving any mode full-stops before provisioning next.
func set_mode(next: Mode) -> void:
	if next == mode and (next == Mode.OFF or is_active()):
		if next != Mode.OFF:
			refresh()
		return

	var previous := mode
	_stop_runtimes()
	mode = Mode.OFF
	if previous != Mode.OFF:
		TomeDebug.log(
			"Voice",
			"Deprovisioned (leaving_%s_for_%s)" % [_mode_label(previous), _mode_label(next)]
		)

	if next == Mode.OFF:
		return

	if not _can_start_voice(next):
		return

	SteamService.allow_p2p_relay()
	var steam_ids := _collect_session_steam_ids()
	var runtime := lobby_runtime if next == Mode.LOBBY else game_runtime
	runtime.set_peers(steam_ids)
	runtime.start()
	if not runtime.is_active():
		TomeDebug.log("Voice", "Failed to start voice for mode=%s" % _mode_label(next))
		return

	mode = next
	TomeDebug.log("Voice", "Mode set to %s" % _mode_label(mode))
	_log_refresh_snapshot()


func refresh() -> void:
	if mode == Mode.OFF:
		return
	var runtime := _active_runtime()
	if runtime == null or not runtime.is_active():
		return
	if not NetworkManager.is_session_active and not GameState.is_multiplayer:
		return

	runtime.set_peers(_collect_session_steam_ids())
	runtime.refresh()
	_log_refresh_snapshot()


func _active_runtime() -> VoiceRuntime:
	match mode:
		Mode.LOBBY:
			return lobby_runtime
		Mode.GAME:
			return game_runtime
		_:
			return null


func _stop_runtimes() -> void:
	if lobby_runtime != null:
		lobby_runtime.stop()
	if game_runtime != null:
		game_runtime.stop()


func _can_start_voice(next: Mode) -> bool:
	if lobby_runtime == null or game_runtime == null:
		return false
	if not SteamService.is_ready() or not Engine.has_singleton("Steam"):
		TomeDebug.log("Voice", "Cannot start %s — Steam unavailable" % _mode_label(next))
		return false
	match next:
		Mode.LOBBY:
			if not NetworkManager.is_session_active:
				TomeDebug.log("Voice", "Cannot start LOBBY — not in a network lobby")
				return false
		Mode.GAME:
			if not GameState.is_multiplayer and not NetworkManager.is_session_active:
				TomeDebug.log("Voice", "Cannot start GAME — no multiplayer session")
				return false
		_:
			return false
	return true


func _build_runtimes() -> void:
	if lobby_runtime != null:
		return

	var lobby_cfg := VoiceContextConfig.new()
	lobby_cfg.label = &"lobby"
	lobby_cfg.binding = VoiceContextConfig.Binding.EPHEMERAL_CLUSTER
	lobby_cfg.proximity = ProximitySettings.new()
	lobby_cfg.proximity.enabled = false
	lobby_cfg.proximity.configuration = ProximityConfiguration.new()

	var game_cfg := VoiceContextConfig.new()
	game_cfg.label = &"game"
	game_cfg.binding = VoiceContextConfig.Binding.MEMBERS
	# proximity defaults: enabled, 8 m buffer / 40 m range (library game-ready)

	lobby_runtime = VoiceRuntime.new()
	lobby_runtime.name = "LobbyRuntime"
	lobby_runtime.config = lobby_cfg
	lobby_runtime.log_level = VoiceRuntime.LogLevel.DEBUG
	lobby_runtime.log_message.connect(_on_runtime_log)
	add_child(lobby_runtime)

	game_runtime = VoiceRuntime.new()
	game_runtime.name = "GameRuntime"
	game_runtime.config = game_cfg
	game_runtime.log_level = VoiceRuntime.LogLevel.DEBUG
	game_runtime.log_message.connect(_on_runtime_log)
	add_child(game_runtime)


func _collect_session_steam_ids() -> Array[int]:
	var tree := get_tree()
	if tree == null:
		return []
	var mp := tree.get_multiplayer()
	var steam_ids := SteamMultiplayerPeerAdapterScript.collect_session_steam_ids(mp)
	if not SteamService.is_ready():
		return steam_ids
	var lobby_id := SteamService.current_lobby_id
	if lobby_id == 0:
		return steam_ids
	var merged: Array[int] = steam_ids.duplicate()
	for index in range(SteamService.get_lobby_member_count(lobby_id)):
		var member_id := SteamService.get_lobby_member_by_index(index, lobby_id)
		if member_id == 0 or member_id == SteamService.get_steam_id():
			continue
		if not merged.has(member_id):
			merged.append(member_id)
	return merged


func _mode_label(value: Mode) -> String:
	match value:
		Mode.LOBBY:
			return "lobby"
		Mode.GAME:
			return "game"
		_:
			return "off"


func _log_refresh_snapshot() -> void:
	var runtime := _active_runtime()
	var session := get_session()
	var channel := session.get_primary_channel() if session != null else null
	var speakers: Array = []
	var has_listener := false
	if channel != null:
		speakers = channel.get_registered_speaker_ids()
		has_listener = channel.get_listener_node() != null
	var peers: Array = []
	if session != null:
		peers = session.get_session_peers()
	TomeDebug.log(
		"Voice",
		"Refreshed mode=%s peers=%s speakers=%s listener=%s runtime=%s"
		% [
			_mode_label(mode),
			peers,
			speakers,
			has_listener,
			runtime.name if runtime != null else "none",
		]
	)


func _on_runtime_log(_level: VoiceRuntime.LogLevel, event: String, detail: String) -> void:
	if detail.is_empty():
		TomeDebug.log("Voice", event)
	else:
		TomeDebug.log("Voice", "%s — %s" % [event, detail])


func _on_peer_connected(peer_id: int) -> void:
	TomeDebug.log("Voice", "Peer connected id=%s — refreshing" % peer_id)
	call_deferred("refresh")


func _on_peer_disconnected(peer_id: int) -> void:
	TomeDebug.log("Voice", "Peer disconnected id=%s — refreshing" % peer_id)
	call_deferred("refresh")


func _on_steam_lobby_member_joined(steam_id: int) -> void:
	TomeDebug.log("Voice", "Lobby member joined steam_id=%s — refreshing" % steam_id)
	call_deferred("refresh")
