class_name ApprenticeSkillTreeDefinition
extends SkillTreeDefinition

## Apprentice trees grant exactly one spell/unlock per starting node.

@export var node_spell_ids: Dictionary = {}


func get_role_kind() -> String:
	return "apprentice"


func allows_multiple_unlocks_per_node() -> bool:
	return false


func get_unlock_ids_for_node(node_id: String) -> Array[String]:
	if not is_valid_starting_node(node_id):
		return []
	var node := get_node(node_id)
	if node != null and not node.spell_ids.is_empty():
		return node.spell_ids.duplicate()
	if node_spell_ids.has(node_id):
		return [String(node_spell_ids[node_id])]
	return [node_id]
