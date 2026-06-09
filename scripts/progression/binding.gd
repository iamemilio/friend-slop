class_name Binding
extends RefCounted

## Skill-tree access for a player (tree type + starting node in that tree).

const DEFAULT_TREE_ID := "firemage"
const DEFAULT_WARDEN_TREE_ID := "warden"
const DEFAULT_FIREMAGE_TREE := preload("res://resources/progression/firemage_skill_tree.tres")
const DEFAULT_WARDEN_TREE := preload("res://resources/progression/warden_skill_tree.tres")

const TREES_BY_ID: Dictionary = {
	DEFAULT_TREE_ID: DEFAULT_FIREMAGE_TREE,
	DEFAULT_WARDEN_TREE_ID: DEFAULT_WARDEN_TREE,
}

var tree_id: String = DEFAULT_TREE_ID
var starting_node_id: String = ""


static func create_default() -> Binding:
	return create_for_role(GameState.PlayerRole.APPRENTICE)


static func create_for_role(role: int) -> Binding:
	if role == GameState.PlayerRole.WARDEN:
		return create_for_tree(DEFAULT_WARDEN_TREE)
	return create_for_tree(DEFAULT_FIREMAGE_TREE)


static func create_for_tree(tree: SkillTreeDefinition) -> Binding:
	var binding := Binding.new()
	binding.tree_id = tree.tree_id
	binding.starting_node_id = tree.get_default_starting_node_id()
	return binding


static func from_dict(data: Dictionary) -> Binding:
	var binding := create_default()
	if data.is_empty():
		return binding
	binding.tree_id = String(data.get("tree_id", DEFAULT_TREE_ID))
	var requested_start := String(data.get("starting_node_id", ""))
	var tree := binding.get_tree_definition()
	if tree.is_valid_starting_node(requested_start):
		binding.starting_node_id = requested_start
	elif data.has("starting_node_index"):
		var index := int(data.get("starting_node_index", 0))
		if index >= 0 and index < tree.starting_node_ids.size():
			binding.starting_node_id = tree.starting_node_ids[index]
	return binding


func get_tree_definition() -> SkillTreeDefinition:
	if TREES_BY_ID.has(tree_id):
		return TREES_BY_ID[tree_id]
	return DEFAULT_FIREMAGE_TREE


func to_dict() -> Dictionary:
	return {
		"tree_id": tree_id,
		"starting_node_id": starting_node_id,
	}


func summary() -> String:
	var tree := get_tree_definition()
	return "%s · %s" % [tree.display_name, tree.get_node_label(starting_node_id)]


func build_skill_tree() -> SkillTree:
	return SkillTree.from_binding(self)
