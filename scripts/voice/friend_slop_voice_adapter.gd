extends Node

## Friend Slop thin adapter — wires godot-steam-voice to player heads, maze muffling, match phase.

const VoiceSessionScript := preload("res://addons/godot-steam-voice/voice_session.gd")
const VoiceChannelScript := preload("res://addons/godot-steam-voice/voice_channel.gd")
const MufflingMapScript := preload("res://addons/godot-steam-voice/muffling_map.gd")
const SteamMultiplayerPeerAdapterScript := preload(
	"res://addons/godot-steam-voice/adapters/steam_multiplayer_peer_adapter.gd"
)

var session: VoiceSession
var proximity_channel: VoiceChannel
var _players_root: Node3D


func _ready() -> void:
	_build_session()
	if MatchStateManager.snapshot_changed.is_connected(_on_match_snapshot_changed):
		MatchStateManager.snapshot_changed.disconnect(_on_match_snapshot_changed)
	MatchStateManager.snapshot_changed.connect(_on_match_snapshot_changed)


func _build_session() -> void:
	if session != null:
		return
	session = VoiceSessionScript.new()
	session.name = "VoiceSession"
	add_child(session)
	proximity_channel = VoiceChannelScript.new()
	proximity_channel.name = "Proximity"
	proximity_channel.channel_name = "Proximity"
	proximity_channel.preset = VoiceChannel.Preset.PROXIMITY
	proximity_channel.use_wall_muffling = true
	session.add_child(proximity_channel)


func setup_for_match(players_root: Node3D) -> void:
	if not GameState.is_multiplayer:
		return
	_players_root = players_root
	_register_players_in_tree()


func register_local_player(player: CharacterBody3D) -> void:
	_bind_player(player)


func register_peer_player(player: CharacterBody3D) -> void:
	_bind_player(player)


func on_maze_ready(maze: Node3D) -> void:
	if session == null or not GameState.is_multiplayer:
		return
	if not maze.has_method("get_wall_grid") or not maze.has_method("world_to_cell"):
		return
	session.muffling_map = MufflingMapScript.from_wall_grid(
		maze.get_wall_grid(),
		Callable(maze, "world_to_cell")
	)
	session.set_session_peers(
		SteamMultiplayerPeerAdapterScript.collect_session_steam_ids(get_tree().get_multiplayer())
	)
	session.start()


func end_voice() -> void:
	if session != null and session.is_active:
		session.stop()


func _bind_player(player: CharacterBody3D) -> void:
	if proximity_channel == null or player == null:
		return
	var head: Node3D = player.get_node_or_null("Head") as Node3D
	if head == null:
		return
	if player.is_multiplayer_authority():
		proximity_channel.register_listener(head)
	else:
		var steam_id := _steam_id_for_player(player)
		if steam_id != 0:
			proximity_channel.register_speaker(steam_id, head)


func _register_players_in_tree() -> void:
	if _players_root == null:
		return
	for child in _players_root.get_children():
		if child is CharacterBody3D:
			_bind_player(child as CharacterBody3D)


func _steam_id_for_player(player: Node) -> int:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return 0
	var peer_id := int(player.name)
	return SteamMultiplayerPeerAdapterScript.get_steam_id_for_peer(peer, peer_id)


func _on_match_snapshot_changed(_snapshot: Dictionary) -> void:
	if proximity_channel == null:
		return
	var phase := MatchStateManager.get_phase()
	var spatial_active := phase == MatchState.Phase.ACTIVE
	proximity_channel.set_rule_enabled("ProximityVolume", spatial_active)
	proximity_channel.set_rule_enabled("WallMuffling", spatial_active)
