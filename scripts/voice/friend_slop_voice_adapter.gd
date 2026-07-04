extends Node

## Friend Slop thin adapter — wires godot-steam-voice session, maze muffling, match phase.
## Per-player spatial audio uses PlayableVoiceMember on character scenes.

const VoiceSessionScript := preload("res://addons/godot-steam-voice/voice_session.gd")
const VoiceChannelScript := preload("res://addons/godot-steam-voice/voice_channel.gd")
const MufflingMapScript := preload("res://addons/godot-steam-voice/muffling_map.gd")
const SteamMultiplayerPeerAdapterScript := preload(
	"res://addons/godot-steam-voice/adapters/steam_multiplayer_peer_adapter.gd"
)

var session: VoiceSession
var proximity_channel: VoiceChannel


func _ready() -> void:
	_build_session()
	if MatchStateManager.snapshot_changed.is_connected(_on_match_snapshot_changed):
		MatchStateManager.snapshot_changed.disconnect(_on_match_snapshot_changed)
	MatchStateManager.snapshot_changed.connect(_on_match_snapshot_changed)


func get_voice_session() -> VoiceSession:
	return session


func _build_session() -> void:
	if session != null:
		return
	session = VoiceSessionScript.new()
	session.name = "VoiceSession"
	add_child(session)
	session.session_started.connect(_on_voice_session_started)
	proximity_channel = VoiceChannelScript.new()
	proximity_channel.name = "Proximity"
	proximity_channel.channel_name = "Proximity"
	proximity_channel.preset = VoiceChannel.Preset.PROXIMITY
	proximity_channel.use_wall_muffling = true
	session.add_child(proximity_channel)


func on_maze_ready(maze: Node3D) -> void:
	if session == null or not GameState.is_multiplayer:
		TomeDebug.log(
			"Voice",
			"Skipped — session=%s multiplayer=%s"
			% [session != null, GameState.is_multiplayer]
		)
		return
	if not maze.has_method("get_wall_grid") or not maze.has_method("world_to_cell"):
		TomeDebug.log("Voice", "Skipped — maze missing wall grid helpers")
		return
	if not SteamService.is_ready():
		TomeDebug.log(
			"Voice",
			"Cannot start — Steam not ready (launch Steam client and restart Godot)"
		)
		return
	if not Engine.has_singleton("Steam"):
		TomeDebug.log(
			"Voice",
			"Cannot start — GodotSteam not loaded (see docs/STEAM_SETUP.md)"
		)
		return

	SteamService.allow_p2p_relay()

	if session.is_active:
		session.stop()

	session.muffling_map = MufflingMapScript.from_wall_grid(
		maze.get_wall_grid(),
		Callable(maze, "world_to_cell")
	)
	var steam_ids := SteamMultiplayerPeerAdapterScript.collect_session_steam_ids(
		get_tree().get_multiplayer()
	)
	session.set_session_peers(steam_ids)
	TomeDebug.log(
		"Voice",
		"Starting proximity voice — steam peers=%s local_steam_id=%s"
		% [steam_ids, SteamService.get_steam_id()]
	)
	session.start()
	if not session.is_active:
		TomeDebug.log(
			"Voice",
			"Failed to start — GodotSteam voice transport unavailable"
		)


func _on_voice_session_started() -> void:
	var channel := proximity_channel
	var listener := channel.get_listener_node() if channel != null else null
	var speaker_ids: Array[int] = []
	if channel != null:
		speaker_ids = channel.get_registered_speaker_ids()
	TomeDebug.log(
		"Voice",
		"Session active — listener=%s speakers=%s phase=%s"
		% [
			listener != null,
			speaker_ids,
			MatchState.phase_to_string(MatchStateManager.get_phase()),
		]
	)


func end_voice() -> void:
	if session != null and session.is_active:
		session.stop()


func _on_match_snapshot_changed(_snapshot: Dictionary) -> void:
	if proximity_channel == null:
		return
	var phase := MatchStateManager.get_phase()
	var spatial_active := phase == MatchState.Phase.ACTIVE
	proximity_channel.set_rule_enabled("ProximityVolume", spatial_active)
	proximity_channel.set_rule_enabled("WallMuffling", spatial_active)
