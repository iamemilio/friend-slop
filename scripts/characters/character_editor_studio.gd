@tool
extends Node3D

## Lit studio backdrop for fine-editing a character scene in isolation.
## Visible only while this character scene is the one open in the editor.
## Hidden when the character is instanced under main / workspaces; freed at runtime.


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	_sync_studio_state()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_studio_state()


func _sync_studio_state() -> void:
	var active := _is_editing_owner_character()
	visible = active
	for child in get_children():
		if child is Camera3D:
			(child as Camera3D).current = active


func _is_editing_owner_character() -> bool:
	if not is_inside_tree():
		return false
	var edited: Node = get_tree().edited_scene_root
	if edited == null:
		return false
	## Parent is the Character / PlayableCharacter / Apprentice / Warden root.
	return edited == get_parent()
