class_name DiscoverablePlacement
extends RefCounted

var definition_id: String = ""
var variant_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var instance_seed: int = 0


func _init(
	p_definition_id: String = "",
	p_variant_id: String = "",
	p_cell: Vector2i = Vector2i.ZERO,
	p_instance_seed: int = 0
) -> void:
	definition_id = p_definition_id
	variant_id = p_variant_id
	cell = p_cell
	instance_seed = p_instance_seed
