@tool
extends Node3D

## Isolated 3D studio for fine-editing one character (not used in match play).
## Open from FileSystem — separate from main.tscn maze view.


func _enter_tree() -> void:
	set_meta("character_preview_scene", true)
