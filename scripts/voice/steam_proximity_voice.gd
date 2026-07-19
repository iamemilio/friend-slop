class_name SteamProximityVoice
extends VoiceMember

## Proximity voice anchor — attach as a child of the player Head node.


func _register_with_session() -> void:
	if _is_character_preview_placeholder():
		return
	super._register_with_session()


func _find_voice_session() -> VoiceSession:
	return SteamProximityVoiceHub.get_session()


func _is_character_preview_placeholder() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.is_in_group("player_spawn_slot"):
			return true
		node = node.get_parent()
	if is_inside_tree():
		var scene := get_tree().current_scene
		if scene != null and scene.has_meta("character_preview_scene"):
			return true
	return false
