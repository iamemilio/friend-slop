class_name Interactable
extends Area3D

## Base class for F-key interactables in the maze.

@export var prompt_text: String = "Interact [F]"

var _player_inside: bool = false


func _ready() -> void:
	add_to_group("interactable")
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func get_prompt() -> String:
	return prompt_text


func is_player_in_range() -> bool:
	return _player_inside


func can_interact(_player: Node) -> bool:
	return _player_inside


func interact(_player: Node) -> void:
	pass
