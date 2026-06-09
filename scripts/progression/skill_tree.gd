class_name SkillTree
extends RefCounted

## Runtime view of a player's unlocked nodes from a binding's starting position.

var definition: SkillTreeDefinition
var starting_node_id: String = ""
var unlocked_node_ids: Array[String] = []


static func from_binding(binding: Binding) -> SkillTree:
	var tree := SkillTree.new()
	tree.definition = binding.get_tree_definition()
	tree.starting_node_id = binding.starting_node_id
	tree.unlocked_node_ids = [binding.starting_node_id]
	return tree


func allows_multiple_unlocks_per_node() -> bool:
	return definition.allows_multiple_unlocks_per_node() if definition != null else false


func knows_node(node_id: String) -> bool:
	return unlocked_node_ids.has(node_id)


func get_display_name() -> String:
	return definition.display_name if definition != null else "Unknown"


func get_starting_node_label() -> String:
	if definition == null:
		return starting_node_id
	return definition.get_node_label(starting_node_id)


func get_starting_spell_ids() -> Array[String]:
	if definition == null:
		return []
	return definition.get_starting_spell_ids(starting_node_id)


func get_starting_unlock_ids() -> Array[String]:
	if definition == null:
		return []
	return definition.get_starting_unlock_ids(starting_node_id)
