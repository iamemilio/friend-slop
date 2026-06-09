class_name TestBinding
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")
const BindingScript := preload("res://scripts/progression/binding.gd")
const PlayerCharacterConfigScript := preload("res://scripts/match/player_character_config.gd")


func run() -> int:
	var failures := 0
	failures += _test_default_firemage_start()
	failures += _test_dict_round_trip()
	failures += _test_invalid_start_clamps_to_default()
	failures += _test_legacy_index_migration()
	failures += _test_warden_default_tree()
	return failures


func _test_default_firemage_start() -> int:
	var binding := BindingScript.create_default()
	if binding.tree_id != "firemage":
		push_error("Expected default binding to use firemage tree")
		return 1
	if binding.starting_node_id.is_empty():
		push_error("Expected default binding to pick a starting node")
		return 1
	return 0


func _test_dict_round_trip() -> int:
	var binding := BindingScript.create_default()
	binding.starting_node_id = "haste"
	var restored := BindingScript.from_dict(binding.to_dict())
	if restored.starting_node_id != "haste":
		push_error("Expected binding round-trip to preserve starting node")
		return 1
	return 0


func _test_invalid_start_clamps_to_default() -> int:
	var restored := BindingScript.from_dict({
		"tree_id": "firemage",
		"starting_node_id": "invalid-node",
	})
	if restored.starting_node_id != BindingScript.DEFAULT_FIREMAGE_TREE.get_default_starting_node_id():
		push_error("Expected invalid starting node to fall back to default")
		return 1
	return 0


func _test_legacy_index_migration() -> int:
	var config := PlayerCharacterConfigScript.from_dict({
		"role": GameStateScript.PlayerRole.APPRENTICE,
		"survivor_binding_index": 1,
	})
	if config.binding.starting_node_id != "fireball":
		push_error("Expected legacy binding index to map to fireball starting node")
		return 1
	return 0


func _test_warden_default_tree() -> int:
	var binding := BindingScript.create_for_role(GameStateScript.PlayerRole.WARDEN)
	if binding.tree_id != "warden":
		push_error("Expected warden binding to use warden tree")
		return 1
	if binding.starting_node_id != "hunter":
		push_error("Expected warden binding to default to hunter starting position")
		return 1
	return 0
