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
	if SteamService.lobby_member_joined.is_connected(_on_steam_lobby_member_joined):
		SteamService.lobby_member_joined.disconnect(_on_steam_lobby_member_joined)
	SteamService.lobby_member_joined.connect(_on_steam_lobby_member_joined)


func get_session() -> VoiceSession:
	return session


func start_session() -> void:
	if session == null or not GameState.is_multiplayer:
		return
	if not SteamService.is_ready() or not Engine.has_singleton("Steam"):
		TomeDebug.log("Voice", "Cannot start — Steam/GodotSteam unavailable")
		return
	SteamService.allow_p2p_relay()
	refresh_session()
	if session.is_active:
		return
	session.start()
	if session.is_active:
		TomeDebug.log(
			"Voice",
			"Proximity voice started — peers=%s" % [session.get_session_peers()]
		)
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


func refresh_session() -> void:
	if session == null or not GameState.is_multiplayer:
		return
	if not session.is_active and not MatchStateManager.is_gameplay_active():
		return
	var steam_ids := _collect_session_steam_ids()
	session.set_session_peers(steam_ids)
	if session.is_active:
		session.refresh_member_bindings()
		TomeDebug.log("Voice", "Session refreshed — peers=%s" % [steam_ids])


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


func _on_peer_connected(_peer_id: int) -> void:
	call_deferred("refresh_session")


func _on_steam_lobby_member_joined(_steam_id: int) -> void:
	call_deferred("refresh_session")
