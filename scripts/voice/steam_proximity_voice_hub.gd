extends Node

## One proximity voice session for the whole game. Each player Head has a SteamProximityVoice child.

const VoiceSessionScript := preload("res://addons/godot-steam-voice/voice_session.gd")
const VoiceChannelScript := preload("res://addons/godot-steam-voice/voice_channel.gd")
const SteamMultiplayerPeerAdapterScript := preload(
	"res://addons/godot-steam-voice/adapters/steam_multiplayer_peer_adapter.gd"
)

var session: VoiceSession


func _ready() -> void:
	_build_session()
	if NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.disconnect(_on_peer_connected)
	NetworkManager.peer_connected.connect(_on_peer_connected)


func get_session() -> VoiceSession:
	return session


func start_session() -> void:
	if session == null or not GameState.is_multiplayer:
		return
	if not SteamService.is_ready() or not Engine.has_singleton("Steam"):
		TomeDebug.log("Voice", "Cannot start — Steam/GodotSteam unavailable")
		return
	SteamService.allow_p2p_relay()
	_refresh_peers()
	if session.is_active:
		session.refresh_member_bindings()
		return
	session.start()
	if session.is_active:
		TomeDebug.log("Voice", "Proximity voice started — peers=%s" % session.get_session_peers())
	else:
		TomeDebug.log("Voice", "Proximity voice failed to start")


func stop_session() -> void:
	if session != null and session.is_active:
		session.stop()


func _build_session() -> void:
	if session != null:
		return
	session = VoiceSessionScript.new()
	session.name = "ProximityVoiceSession"
	add_child(session)
	var channel := VoiceChannelScript.new()
	channel.name = "Proximity"
	channel.channel_name = "Proximity"
	channel.preset = VoiceChannel.Preset.PROXIMITY
	channel.use_wall_muffling = false
	channel.near_full_volume_m = 8.0
	channel.far_silent_m = 40.0
	session.add_child(channel)


func _refresh_peers() -> void:
	if session == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var steam_ids := SteamMultiplayerPeerAdapterScript.collect_session_steam_ids(
		tree.get_multiplayer()
	)
	session.set_session_peers(steam_ids)


func _on_peer_connected(_peer_id: int) -> void:
	if session == null or not session.is_active:
		return
	call_deferred("_refresh_peers_and_members")


func _refresh_peers_and_members() -> void:
	if session == null or not session.is_active:
		return
	_refresh_peers()
	session.refresh_member_bindings()
