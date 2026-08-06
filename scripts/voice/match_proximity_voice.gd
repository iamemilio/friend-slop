class_name MatchProximityVoice
extends Node

## Match-side owner of spatial voice: tells the live VoiceSession which character
## body each remote peer speaks from, so playback pans and attenuates with the
## authored ProximityChatSettings on Match/VoiceSession/Listeners/Chat.
##
## Without a binding a peer stays flat/open-mic, so this node is what turns match
## chat into proximity chat. Bind after players spawn and whenever a peer joins.

## A peer whose Steam ID has not resolved yet cannot be anchored; retry instead of
## leaving them permanently non-spatial.
const RESOLVE_RETRY_SEC := 1.0

var _bound_steam_ids: Dictionary = {} ## peer_id -> anchored steam_id
var _unresolved: Dictionary = {} ## peer_id -> CharacterBody3D awaiting a Steam ID
var _retry_queued: bool = false


func _ready() -> void:
	if not NetworkManager.peer_disconnected.is_connected(unbind_peer):
		NetworkManager.peer_disconnected.connect(unbind_peer)


## players_root child names are peer ids (see NetworkManager.spawn_player_for_peer).
func bind_players(players_root: Node) -> void:
	if players_root == null:
		return
	for child in players_root.get_children():
		if child is CharacterBody3D:
			bind_peer(int(String(child.name)), child as CharacterBody3D)


func bind_peer(peer_id: int, body: CharacterBody3D) -> void:
	if peer_id <= 0 or body == null:
		return
	var session := _session()
	if session == null:
		return
	var steam_id := SteamProximityVoiceHub.resolve_steam_id_for_peer(peer_id)
	if steam_id == 0:
		## resolve_steam_id_for_peer already logged the missing mapping.
		_unresolved[peer_id] = body
		_queue_resolve_retry()
		return
	_unresolved.erase(peer_id)
	if steam_id == SteamService.get_steam_id():
		## The local player is the listener, not a remote emitter.
		return
	if int(_bound_steam_ids.get(peer_id, 0)) == steam_id:
		return
	_bound_steam_ids[peer_id] = steam_id
	session.call("set_peer_anchor", steam_id, body)
	TomeDebug.log(
		"ProximityVoice",
		"peer=%d steam_id=%d anchored to '%s' proximity=%s"
		% [peer_id, steam_id, body.name, _proximity_label(session)]
	)


func unbind_peer(peer_id: int) -> void:
	_unresolved.erase(peer_id)
	var steam_id := int(_bound_steam_ids.get(peer_id, 0))
	if steam_id == 0:
		return
	_bound_steam_ids.erase(peer_id)
	var session := _session()
	if session != null:
		session.call("clear_peer_anchor", steam_id)
	TomeDebug.log("ProximityVoice", "peer=%d steam_id=%d unanchored" % [peer_id, steam_id])


func _queue_resolve_retry() -> void:
	if _retry_queued or not is_inside_tree():
		return
	_retry_queued = true
	get_tree().create_timer(RESOLVE_RETRY_SEC).timeout.connect(
		_retry_unresolved,
		CONNECT_ONE_SHOT
	)


func _retry_unresolved() -> void:
	_retry_queued = false
	for peer_id in _unresolved.keys():
		var body := _unresolved[peer_id] as CharacterBody3D
		if body == null or not is_instance_valid(body):
			_unresolved.erase(peer_id)
			continue
		bind_peer(int(peer_id), body)


func _session() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var app := tree.get_first_node_in_group("game_app")
	if app == null or not app.has_method("get_active_voice_session"):
		return null
	return app.call("get_active_voice_session") as Node


func _proximity_label(session: Node) -> String:
	if not session.has_method("is_proximity_active"):
		return "unknown"
	return "on" if bool(session.call("is_proximity_active")) else "off"
