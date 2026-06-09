class_name TestSkillTree
extends RefCounted

const BindingScript := preload("res://scripts/progression/binding.gd")
const FiremageTree := preload("res://resources/progression/firemage_skill_tree.tres")


func run() -> int:
	var failures := 0
	failures += _test_firemage_starting_nodes()
	failures += _test_binding_starting_spell()
	failures += _test_node_detail_includes_spell()
	return failures


func _test_firemage_starting_nodes() -> int:
	var tree := FiremageTree
	if not tree.is_valid_starting_node("show_me"):
		push_error("Expected show_me to be a valid Firemage starting node")
		return 1
	if tree.get_node("show_me") == null:
		push_error("Expected Firemage tree to know show_me node")
		return 1
	return 0


func _test_binding_starting_spell() -> int:
	var binding := BindingScript.create_for_role(GameState.PlayerRole.APPRENTICE)
	binding.starting_node_id = "show_me"
	var tree := binding.get_tree_definition()
	if tree.get_node("show_me") == null:
		push_error("Expected binding tree to know show_me")
		return 1
	return 0


func _test_node_detail_includes_spell() -> int:
	var firemage := FiremageTree
	var show_me := firemage.get_node("show_me")
	if show_me == null or show_me.spell_ids.is_empty():
		push_error("Expected show_me node to declare its starting spell")
		return 1
	var detail := firemage.build_node_detail_text("show_me", {"show_me": "Show Me"})
	if not detail.contains("Show Me") or not detail.contains("Starting kit"):
		push_error("Expected show_me detail text to include spell label")
		return 1
	return 0
