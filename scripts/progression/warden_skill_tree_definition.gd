class_name WardenSkillTreeDefinition
extends SkillTreeDefinition

## Warden trees grant multiple powers from each starting position.

@export var starting_node_spells: Dictionary = {}


func get_role_kind() -> String:
	return "warden"


func allows_multiple_unlocks_per_node() -> bool:
	return true


func get_unlock_ids_for_node(node_id: String) -> Array[String]:
	if not is_valid_starting_node(node_id):
		return []
	var node := get_node(node_id)
	if node != null and not node.spell_ids.is_empty():
		return node.spell_ids.duplicate()
	if starting_node_spells.has(node_id):
		var unlock_ids: Array[String] = []
		for entry in starting_node_spells[node_id]:
			unlock_ids.append(String(entry))
		return unlock_ids
	return []
